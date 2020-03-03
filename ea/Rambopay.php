<?php
namespace app\index\controller;

use app\index\model\orders;
use services\Error;
use services\RedisCache;
use services\myCryptAES;
use think\Db;
use think\Validate;

class Rambopay{
    protected $error;
    protected $param = [];
    protected $myCryptAES;
    protected $error_code_show = false;
    protected $error_code_lang = '';
    protected $pay_type = [1=>'Bank',2=>'WeChat',3=>'AliPay'];
    protected $lanbo_status = [702=>1,703=>0,704=>2,705=>3,706=>4];
    protected $bank_code = '';
    protected $is_unlock = false;
    public function __construct()
    {

        $this->error = new Error();
        $this->myCryptAES = new myCryptAES();
        $this->param = request()->param();
        $this->error_code_lang = isset($this->param['LG']) ? $this->param['LG'] : Error::LANG_UNDIFINED;    //后续根据所传参数设置错误语言,不设默认英语
        $this->param['from_ip'] = $_SERVER['REMOTE_ADDR'];
        $this->param['from_systime'] = date("Y-m-d H:i:s",time());

        //todo 开发临时开启
//        $this->param = request()->post();
//        return;

        writelog('Rambopay_in',$this->param);
        if($this->openforip()){
            echo $this->response(['code'=>294,'Ret'=>'2','ip'=>$_SERVER['REMOTE_ADDR']]);exit;
        }
        if(isset($this->param['bankType']) && !empty($this->param['bankType'])){
            $this->bank_code = $this->param['bankType'];
        }
        if(isset($this->param['data']) && !empty($this->param['data'])){
            $this->param = $this->myCryptAES->decrypt($this->param['data']);
        }else{
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }

        if(!$this->param){
            echo $this->response(['code'=>292,'Ret'=>'2']);exit;
        }
    }
    private function openforip(){
        $askip = request()->ip();

        if(isset($this->param['token']) && isset($this->param['data']) && !empty($this->param['token']) && !empty($this->param['data'])){
            $result = RedisCache::get($this->param['token']);
            if($result!=false && $result==$this->param['data']){
                $this->is_unlock = true;
                return false;
            }
        }
        if(!in_array($askip,config('conf._OPENIP'))){
            return true;
        }else{
            return false;
        }
    }
    //兰博接口，存款
    public function pay(){
        $validate = new Validate([
            'RootID' => 'require',
            'PaymentMethod' => 'require',
            'OrderNo' => 'require',
            'Amount' => 'require',
            'Device' => 'require|in:0,1',
            'PaymentCurrency' => 'require'
        ]);

        if (!$validate->check($this->param)) {
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }

        //检测订单号
        $this->checkOrder($this->param['OrderNo']);

        //检测商户
        $deposit=$this->checkPayBucode($this->param);

        //获取金流商接口url
        $urlArr = $this->getApiUrl($deposit['merchant_id'], $this->param['PaymentMethod']);
        $deposit = array_merge($deposit, $urlArr);

        //查看金流商是否有此功能
        $array=[1,2,4];
        $merchantt_info= $this->checkMerchantt($deposit,$array);

        //新增获取支付方式有效时长
        $merchant_type_info = Db::table('merchant_pay_type_list')
            ->where(['pay_type_id' => $this->param['PaymentMethod'], 'merchant_id' => $deposit['merchant_id'], 'status' => 1])
            ->find();

        if (!$merchant_type_info){
            writelog('pay-error', "金流商支付方式不存在, pay_type_id: {$this->param['PaymentMethod']}, merchant_id: {$deposit['merchant_id']}");
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }
        $deposit['effective_time'] = isset($merchant_type_info['effective_time']) && $merchant_type_info['effective_time'] > 0 ? $merchant_type_info['effective_time'] : 30*60;

        //如果是网银支付并且需要页面展示
        if($merchantt_info['is_open_bank']==1 && empty($this->bank_code) && $this->param['PaymentMethod']==1){
            $this->checkBankpage($this->param);
        }

        //传入支付接口参数
        $deposit['pay_type'] = $this->param['PaymentMethod'];
        $deposit['order'] = $this->param['OrderNo'];
        $deposit['amount'] = $this->param['Amount'];
        $deposit['mac'] = $this->param['Device'];
        $deposit['bankCode'] = $this->bank_code;
        $deposit['pay_order_account'] = $this->param['AcctID'] ?? 1;
        $deposit['tagUrl'] = !empty($this->param['TagUrl']) ? $this->param['TagUrl']:'';
        if (isset($this->param['BankCard'])){
            $deposit['bank_card'] = $this->param['BankCard'];
        }

        writelog('pay_in',$deposit);

        //保存订单
        $MerchantInfo = json_decode($deposit['app_json'], true);
        $obj = new Orders();
        $obj->buCode = array_shift($MerchantInfo);
        $obj->order_no = $deposit['order'];
        $obj->pay_order_no = $merchantt_info['action'] . $deposit['order'];
        $obj->pay_order_account = $deposit['pay_order_account']; //该支付使用字段 mac 为0 值为 'aliqrcode' 1 为 'aliwap'
        $obj->pay_channel = $deposit['pay_type'] ?? '';
        $obj->amount = $deposit['amount'];
        $obj->online_deposit_id = $deposit['id'];
        $obj->currency_id = $this->param['PaymentCurrency'];
        $obj->type = 1;
        $obj->create_time = time();
        $obj->pay_type_id = $deposit['pay_type'];
        $obj->effective_time = $deposit['effective_time'];
        $rs = $obj->save();

        if (false == $rs) {
            //echo $this->response(['Ret' => 1, 'Type' => 0, 'Message' => '订单系统出错', 'Data' => '']);exit();
            echo $this->response(['code'=>296,'Ret'=>'1']);exit;
        }

        $merchantt_return = $this->GetPriveteMethod($merchantt_info['action'],'pay',$deposit);
        if(isset($merchantt_return['Type']) && $merchantt_return['Type']==1 && !empty($merchantt_return['Data'])){
            if(isset($merchantt_return['Local']) && $merchantt_return['Local']==1){
                $merchantt_return['Data'] = $this->base64EncodeImage($merchantt_return['Data']);
            }
        }
        echo $this->response($merchantt_return);
    }
    //兰博接口，取款
    public function refund(){
        $validate = new Validate([
            'RootID' => 'require',
            'OnlinePayType' => 'require',
            'Amount' => 'require',
            'PaidoutNo' => 'require',
            'BankAcct' => 'requireIf:OnlinePayType,1',
            'CardName' => 'requireIf:OnlinePayType,1',
            'BankBranch' => 'requireIf:OnlinePayType,1',
            'CurrencyAddress'=>'requireIf:OnlinePayType,2'
        ]);

        if (!$validate->check($this->param)) {
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }
        //检测订单号
        $this->checkOrder($this->param['PaidoutNo']);
        //检测商户
        $deposit=$this->checkRefundBucode($this->param);

        //获取金流商接口url
        $urlArr = $this->getApiUrl($deposit['merchant_id'], 1);
        $deposit = array_merge($deposit, $urlArr);

        //查看金流商是否有此功能
        $array=[2,3,4];
        $merchantt_info= $this->checkMerchantt($deposit,$array);

        //传入支付接口参数
        $deposit['amount'] = $this->param['Amount'];
        $deposit['order'] = $this->param['PaidoutNo'];
        $deposit['bank_code'] = $this->param['BankAcct'] ?? '';
        $deposit['username'] = $this->param['CardName'] ?? '';
        $deposit['bank_address'] = $this->param['BankBranch'] ?? '';
        $deposit['currency_address'] = $this->param['CurrencyAddress'] ?? '';

        echo $this->response($this->GetPriveteMethod($merchantt_info['action'],'refund',$deposit));
    }

    //从数据库拿金流商接口地址，代替原来从配置文件拿取
    private function getApiUrl($merchant_id, $pay_type_id){
        $arr['pay_url'] = "";
        $arr['refund_url'] = "";
        $arr['query_pay_url'] = "";
        $arr['query_refund_url'] = "";
        $arr['query_balance_url'] = "";

        if ($pay_type_id > 0){
            $merchant_pay_type_list = Db::table('merchant_pay_type_list')->where(['merchant_id' => $merchant_id, 'pay_type_id' => $pay_type_id, 'status' => 1])->select();
            if ($merchant_pay_type_list){
                foreach ($merchant_pay_type_list as $k => $v){
                    if ($arr['pay_url'] && $arr['refund_url']) break;

                    if(!$arr['pay_url'] && $v['support_type'] == 1){
                        $arr['pay_url'] = $v['request_url'];
                    }

                    if(!$arr['refund_url'] && $v['support_type'] == 2){
                        $arr['refund_url'] = $v['request_url'];
                    }
                }
            }
        }

        $merchant_url = Db::table('merchant_url')->where(['merchant_id' => $merchant_id])->find();
        if ($merchant_url){
            $urlData = json_decode($merchant_url['url_json'], true);
            if (isset($urlData['pay_query']))  $arr['query_pay_url'] = $urlData['pay_query'];
            if (isset($urlData['refund_query']))  $arr['query_refund_url'] = $urlData['refund_query'];
            if (isset($urlData['balance_query']))  $arr['query_balance_url'] = $urlData['balance_query'];
        }

        return $arr;
    }

    //兰博接口，查询订单
    public function orderStatus(){

        $validate = new Validate([
            'OrderNo' => 'require',
        ]);
        if (!$validate->check($this->param)) {
            echo $this->response(['code'=>295,'Ret'=>'-1']);exit;
        }
        $orders_info = Db::table('orders')->where(['order_no'=>$this->param['OrderNo']])->find();
        if(!$orders_info || empty($orders_info)){
            //echo $this->response(['code'=>2001,'Ret'=>'-1','Message'=>'没有该笔订单或生成订单失败！']);exit;
            echo $this->response(['code'=>2001,'Ret'=>'2']);exit;
        }

        //查询商户信息
        $deposit = Db::table('online_deposit')->where(['id'=>$orders_info['online_deposit_id'],'status'=>1])->find();
        if(!$deposit){
            echo $this->response(['Ret'=>'-1','code'=> '1010']);exit;
        }

        //查询金流商信息
        $merchantt_info = Db::table('merchant')->where(['id'=>$deposit['merchant_id'],'status'=>1])->find();

        if(!$merchantt_info){
            echo $this->response(['Ret'=>'-1','code'=> '1010']);exit;
        }

        $return_data = [];
        $goType = '';
        $deposit['order'] = $this->param['OrderNo'];
        if($orders_info['type']==1){
            $goType = 'OrderQuery';
        }
        if($orders_info['type']==2){
            $goType = 'ReceiveQuery';
        }

        //获取金流商接口url
        $urlArr = $this->getApiUrl($deposit['merchant_id'], 0);
        $deposit = array_merge($deposit, $urlArr);

        $return_data = $this->GetPriveteMethod($merchantt_info['action'],$goType,$deposit);

        $orders_info = Db::table('orders')->where(['order_no'=>$this->param['OrderNo']])->find();
        $return_data['SysOrderNo'] = $orders_info['order_no'];
        $return_data['MerchantOrderNo'] = $orders_info['pay_order_no'];
        $return_data['OnlineApplyType'] = $orders_info['type'];
        $return_data['RootID'] = $deposit['member_id'];
        $return_data['Amount'] = $orders_info['amount'];
        $return_data['SerialNo'] = $deposit['serial_no'];
        $return_data['MerchantAcct'] = $orders_info['buCode'];
        $return_data['CashFlowServerName'] = $merchantt_info['name'];

        echo $this->response($return_data);
    }

    //兰博接口，商户验证支付方式是否正常
    public function merchantValidate(){
        $validate = new Validate([
            'SerialNo'  => 'require',//兰博主键
            'RootID' => 'require',//站长id
            'PaymentMethod' => 'require',//支付类型
            'Amount' => 'require',//金额
        ]);
        if (!$validate->check($this->param)) {
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }

        //检测商户
        $deposit=$this->checkPayBucode($this->param);

        //查看金流商是否有此功能
        $array=[1,2,4];
        $merchantt_info= $this->checkMerchantt($deposit,$array);
        /*//如果是网银支付并且需要页面展示
        if($merchantt_info['is_open_bank']==1 && empty($this->bank_code) && $this->param['PaymentMethod']==1){
            $this->checkBankpage($this->param);
        }*/
        //传入支付接口参数
        $deposit['pay_type'] = $this->param['PaymentMethod'];
        $deposit['order'] = date('YmdHis') . str_pad(mt_rand(1, 99999), 6, '0', STR_PAD_LEFT);
        $deposit['amount'] = $this->param['Amount'];
        $deposit['mac'] = 0;
        $deposit['bankCode'] = $this->bank_code;
        $deposit['pay_order_account'] = $this->param['AcctID'] ?? 1;
        $deposit['tagUrl'] = !empty($this->param['TagUrl']) ? $this->param['TagUrl']:'';

        writelog('pay_in',$deposit);
        $merchantt_return = $this->GetPriveteMethod($merchantt_info['action'],'pay',$deposit);
        /*if(isset($merchantt_return['Type']) && $merchantt_return['Type']==1 && !empty($merchantt_return['Data'])){
            if(isset($merchantt_return['Local']) && $merchantt_return['Local']==1){
                $merchantt_return['Data'] = $this->base64EncodeImage($merchantt_return['Data']);
            }
        }*/
        if($merchantt_return && $merchantt_return['Ret'] == 0){//成功
            echo $this->response(['Ret'=>0,'code','Msg'=>'']);exit;
        }
        writelog('merchantValidate_error',$merchantt_return['Message']);
        //echo $this->response(['code'=>1010,'Ret'=>'2','Msg'=>$merchantt_return['Message']]);exit;
        echo $this->response(['code'=>1010,'Ret'=>'2']);exit;
    }

    //兰博接口，商户信息新增or修改
    public function merchantMgr(){
        $validate = new Validate([
            'SerialNo'  => 'require',
            'RootID' => 'require',
            'MerchantID' => 'require',
            'Status' => 'require',
            'PayTypeId' => 'require',
            'MerchantInfo' => 'require',
            'PayStatus' => 'require|in:0,1,2',
            'RefundStatus' => 'require|in:0,1,2'
        ]);

        $param = $this->param;
        if (!$validate->check($param)) {
            writelog('merchantMgr_error',$validate->getError());
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }

        //可能只支持代付
//        if (!isset($param['LimitData']) || empty($param['LimitData'])){
//            echo $this->response(['code'=>295,'Ret'=>'2', 'Message'=>'限额数据不能为空']);exit;
//        }

        $merchantId = $param['MerchantID'];
        $payTypeId = $param['PayTypeId'];
        if (!$payTypeId && $param['RefundStatus']==1){
            $payTypeId = 1; //代付目前默认是网银
        }

        $data['serial_no'] = $this->param['SerialNo'];
        $data['member_id'] = $this->param['RootID'];
        $data['merchant_id'] = $merchantId;
        $data['pay_status'] = $this->param['PayStatus'];
        $data['refund_status'] = $this->param['RefundStatus'];

        if(array_key_exists($this->param['Status'], $this->lanbo_status)){
            $data['status'] = $this->lanbo_status[$this->param['Status']];
        }else{
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }
        $data['remark'] = $this->param['Remark'] ?? '无';
        $data['currency_type'] = $this->param['PaymentCurrency'] ?? 1;
        $data['app_json'] = $this->param['MerchantInfo'];

        //验证
//        $merchant = Db::table('merchant')->where('id','=',$this->param['MerchantID'])->find();
//        if($data['status']==1){
//            $MerchantObj = new Merchant($data);
//            $rs = $MerchantObj->validate($merchant['action'],$this->param['MerchantInfo']);
//            if(isset($rs['Ret']) && -1 == $rs['Ret'])
//            {
//                echo $this->response(['code'=>1018,'Ret'=>'2']);exit;
//            }
//        }

        $merchantPayTypeInfo = Db::table('merchant_pay_type_list')
            ->where(['merchant_id' => $merchantId, 'pay_type_id' => $payTypeId, 'status' => 1])
            ->find();

        if (!$merchantPayTypeInfo){
            writelog('merchantMgr_error','支付方式不存在');
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }

        $depositPayTypeData = [];
        if (isset($param['LimitData']) && !empty($param['LimitData'])){
            $supportDevicesArray = explode(',', $merchantPayTypeInfo['support_devices']);
            foreach ($param['LimitData'] as $ldk => $ldv){
                if (!in_array($ldv['SupportDevices'], $supportDevicesArray)){
                    writelog('merchantMgr_error','设备类型数据有误');
                    echo $this->response(['code'=>295,'Ret'=>'2']);exit;
                }

                //判断限额
                if(preg_match('/-/',$ldv['LimitAmount'])){
                    $LimitAmount = explode("-",$ldv['LimitAmount']);
                }else{
                    $LimitAmount = explode(",",$ldv['LimitAmount']);
                }

                if (is_array($LimitAmount)){
                    foreach ($LimitAmount as $v){
                        if ($merchantPayTypeInfo['pay_limit'] && !$this->checkLimitAmount($v, $merchantPayTypeInfo['pay_limit'])){
                            echo $this->response(['code'=>2002,'Ret'=>'2']);exit;
                        }
                    }
                }

                if ($merchantPayTypeInfo['day_total_amount_limit'] != -1 &&
                    $ldv['DayTotalAmountLimit'] > $merchantPayTypeInfo['day_total_amount_limit']){
                    echo $this->response(['code'=>2003,'Ret'=>'2']);exit;
                }

                if ($merchantPayTypeInfo['day_total_time_limit'] != -1 &&
                    $ldv['DayTotalTimesLimit'] > $merchantPayTypeInfo['day_total_time_limit']){
                    echo $this->response(['code'=>2004,'Ret'=>'2']);exit;
                }

                //支付方式 和 支持设备 做唯一标识
                $depositPayTypeData[] = [
                    'pay_type_id' => $payTypeId,
                    'support_devices' => $ldv['SupportDevices'],
                    'pay_limit' => $ldv['LimitAmount'],
                    'day_total_amount_limit' => $ldv['DayTotalAmountLimit'],
                    'day_total_time_limit' => $ldv['DayTotalTimesLimit'],
                    'status' => 1
                ];
            }
        }

        //判断SerialNo是否存在记录
        $onlineDeposit = Db::table('online_deposit')->where(['serial_no' => $param['SerialNo']])->find();
        $cur_date = date("Y-m-d H:i:s");

        Db::startTrans();
        if($onlineDeposit){
            $onlineDepositId = $onlineDeposit['id'];
            $data['update_time'] = $cur_date;
            $res = Db::table('online_deposit')->where(['serial_no'=>$data['serial_no']])->update($data);
            if(!$res){
                Db::rollback();
                echo $this->response(['code'=>296,'Ret'=>'1']);exit;
            }
        }else{
            $data['create_time'] = $cur_date;
            $data['update_time'] = $cur_date;
            $onlineDepositId = Db::table('online_deposit')->insertGetId($data);
            if(!$onlineDepositId){
                Db::rollback();
                echo $this->response(['code'=>296,'Ret'=>'1']);exit;
            }
        }

        if (!empty($depositPayTypeData)){
            foreach ($depositPayTypeData as $k => $v){
                $v['online_deposit_id'] = $onlineDepositId;

                $depositPayType = Db::table('online_deposit_pay_type_list')
                    ->where(['online_deposit_id' => $onlineDepositId, 'pay_type_id' => $param['PayTypeId'], 'support_devices' => $v['support_devices']])
                    ->find();

                if ($depositPayType){
                    $v['update_time'] = $cur_date;
                    $res = Db::table('online_deposit_pay_type_list')
                        ->where(['id' => $depositPayType['id']])
                        ->update($v);

                    if (!$res){
                        Db::rollback();
                        writelog('merchantMgr_error','更新商户支付类型失败');
                        echo $this->response(['code'=>296,'Ret'=>'1']);exit;
                    }
                }else{
                    $res = Db::table('online_deposit_pay_type_list')
                        ->insert($v);

                    if (!$res){
                        Db::rollback();
                        writelog('merchantMgr_error','插入商户支付类型失败');
                        echo $this->response(['code'=>296,'Ret'=>'1']);exit;
                    }
                }
            }
        }

        //统一更新整个站长的代付状态
        Db::table('online_deposit')->where(['member_id'=>$this->param['RootID'], 'merchant_id'=>$merchantId])
            ->update(['refund_status' => $this->param['RefundStatus']]);

        Db::commit();
        echo $this->response(['code'=>200,'Ret'=>'0']);exit;
    }

    //兰博接口，商户信息新增or修改
    public function merchantMgr_old(){
        $validate = new Validate([
            'SerialNo'  => 'require',
            'RootID' => 'require',
            'MerchantID' => 'require',
            'Status' => 'require',
            'PaymentMethod' => 'require',
            'MerchantInfo' => 'require',
            'PayStatus' => 'require|in:0,1',
            'RefundStatus' => 'require|in:0,1'
        ]);
        if (!$validate->check($this->param)) {
            echo $this->response(['code'=>295,'Ret'=>'2', 'Message'=>$validate->getError()]);exit;
        }

        $pay_type_arr = explode(',', $this->param['PaymentMethod']);
        $payLimitList = [];
        if ($pay_type_arr){
            if (!isset($this->param['PayLimitList']) ||
                !is_array($this->param['PayLimitList']) ||
                count($this->param['PayLimitList']) != count($pay_type_arr)
            ){
                echo $this->response(['code'=>295,'Ret'=>'2','Message'=>'支付方式不一致']);exit;
            }

            $payLimitList = $this->param['PayLimitList'];
            foreach ($payLimitList as $v){
                if (!isset($v['PayTypeId']) ||
                    !isset($v['LimitAmount']) ||
                    !isset($v['DayTotalAmountLimit']) ||
                    !isset($v['DayTotalTimesLimit'])
                ){
                    echo $this->response(['code'=>295,'Ret'=>'2','Message'=>'限额参数不正确']);exit;
                }

                $merchant = $this->param['MerchantID'];

                //todo 判断PayLimitList 是否在金流商限额内
                $merchantPayTypeInfo = Db::table('merchant_pay_type_list')
                    ->where(['merchant_id' => $merchant, 'pay_type_id' => $v['PayTypeId'], 'status' => 1])
                    ->find();

                if (!$merchantPayTypeInfo){
                    echo $this->response(['code'=>295,'Ret'=>'2','Message'=>'支付方式不存在']);exit;
                }

                if(preg_match('/-/',$v['LimitAmount'])){
                    $limitData = explode("-",$v['LimitAmount']);
                }else{
                    $limitData = explode(",",$v['LimitAmount']);
                }

                if (is_array($limitData)){
                    foreach ($limitData as $lv){
                        if (!$this->checkLimitAmount($lv, $merchantPayTypeInfo['pay_limit'])){
                            echo $this->response(['code'=>295,'Ret'=>'2','Message'=>'单笔限额超出范围']);exit;
                        }
                    }
                }

                if ($merchantPayTypeInfo['day_total_amount_limit'] != -1 &&
                    $v['DayTotalAmountLimit'] > $merchantPayTypeInfo['day_total_amount_limit']){
                    echo $this->response(['code'=>295,'Ret'=>'2','Message'=>'单日总金额超出范围']);exit;
                }

                if ($merchantPayTypeInfo['day_total_time_limit'] != -1 &&
                    $v['DayTotalTimesLimit'] > $merchantPayTypeInfo['day_total_time_limit']){
                    echo $this->response(['code'=>295,'Ret'=>'2','Message'=>'单日总次数超出范围']);exit;
                }
            }
        }

        $data['pay_limit_json'] = $payLimitList ? json_encode($payLimitList, JSON_UNESCAPED_UNICODE) : '';
        $data['serial_no'] = $this->param['SerialNo'];
        $data['member_id'] = $this->param['RootID'];
        $data['merchant_id'] = $this->param['MerchantID'];
        $data['pay_status'] = $this->param['PayStatus'];
        $data['refund_status'] = $this->param['RefundStatus'];
        //$data['bank_limit_amount'] = $this->param['BankLimitAmount'] ?? "0";
        //$data['wechat_limit_amount'] = $this->param['WechatLimitAmount'] ?? "0";
        //$data['alipay_limit_amount'] = $this->param['AlipayLimitAmount'] ?? "0";
        //$data['fictitious_limit_amount'] = $this->param['FictitiousLimitAmount'] ?? "0";
        if(array_key_exists($this->param['Status'], $this->lanbo_status)){
            $data['status'] = $this->lanbo_status[$this->param['Status']];
        }else{
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }
        $data['remark'] = $this->param['Remark'] ?? '无';
        $data['bank_type'] = $this->param['PaymentMethod'];
        $data['currency_type'] = $this->param['PaymentCurrency'] ?? 1;
        $data['app_json'] = $this->param['MerchantInfo'];
        //验证 todo 关闭验证
        /*$merchant = Db::table('merchant')->where('id','=',$this->param['MerchantID'])->find();
        if($data['status']==1){
            $MerchantObj = new Merchant($data);
            $rs = $MerchantObj->validate($merchant['action'],$this->param['MerchantInfo']);
            if(isset($rs['Ret']) && -1 == $rs['Ret'])
            {
                echo $this->response(['code'=>1018,'Ret'=>'2']);exit;
            }
        }*/
        $result = Db::table('online_deposit')->where(['serial_no'=>$data['serial_no']])->find();
        if($result){
            $data['update_time'] = date("Y-m-d H:i:s",time());
            $res = Db::table('online_deposit')->where(['serial_no'=>$data['serial_no']])->update($data);
            if(!$res){
                echo $this->response(['code'=>296,'Ret'=>'1']);exit;
            }
        }else{
            $data['create_time'] = date("Y-m-d H:i:s",time());
            $data['update_time'] = date("Y-m-d H:i:s",time());
            $res = Db::table('online_deposit')->insert($data);
            if(!$res){
                echo $this->response(['code'=>296,'Ret'=>'1']);exit;
            }
        }
        echo $this->response(['code'=>200,'Ret'=>'0']);exit;
    }

    //兰博对接接口，删除金流商, （注意：改版后删除功能为删除商户对应金流商的支付方式）
    public function merchantDel(){
        $validate = new Validate([
            'RootID'  => 'require',
            'SerialNo' => 'require',
            'MerchantId' => 'require',
            'PayTypeId' => 'require'
        ]);

        if (!$validate->check($this->param)) {
            echo $this->response(['code'=>295,'Ret'=>'2']);exit;
        }

        $param = $this->param;

        $result = Db::table('online_deposit')
            ->where(['serial_no'=>$param['SerialNo'], 'merchant_id'=>$param['MerchantId'], 'member_id' => $param['RootID']])
            ->find();

        if (!$result){
            echo $this->response(['code'=>296,'Ret'=>'1','Message'=>'deposit not exist']);exit;
        }

        if (!Db::table('online_deposit_pay_type_list')
            ->where(['pay_type_id' => $param['PayTypeId'], 'online_deposit_id' => $result['id']])
            ->update(['status' => -1])){
            echo $this->response(['code'=>296,'Ret'=>'1']);exit;
        }

        echo $this->response(['code'=>200,'Ret'=>'0']);exit;
    }
    protected function response(array $result)
    {
        $data = [];
        if (! array_key_exists('Message', $result) && array_key_exists('code', $result)) {
            $result['Message'] = $this->getError($result['code']);
        }
        if($this->is_unlock){
            if(isset($result['Data']) && !empty($result['Data'])){
                return $result['Data'];
            }
        }else{
            $data['data'] = $this->myCryptAES->encrypt($result);
//            $data['data'] = $result;    //todo 开发临时关闭加密
            $data['from_ip'] = $_SERVER['REMOTE_ADDR'];
            $data['return_systime'] = date("Y-m-d H:i:s",time());
            writelog('Rambopay_out',$data);
            return json_encode($data);
        }
    }

    protected function getError($code)
    {
        return $this->error->getError($code, $this->error_code_show, $this->error_code_lang);
    }
    /** 调用私有方法
     * @param $class
     * @param $function
     * @return mixed
     * @throws \ReflectionException
     */
    private function GetPriveteMethod($class,$function,$data)
    {
        $className = __NAMESPACE__.'\\'.$class;
        if (!$className || !class_exists($className)) {
            return ['Ret'=>'2','code'=> '1008'];
        }
        $ref_class = new \ReflectionClass($className);
        $instance  = $ref_class->newInstance();
        if(!empty($function) && $ref_class->hasMethod($function)){
            $method = $ref_class->getmethod($function);
            $method->setAccessible(true);
            return $method->invoke($instance,$data);
        }else{
            return ['Ret'=>'2','code'=> '1009'];
        }

    }

    /*
     * 检测订单号
     */
    private function checkOrder($order)
    {
        $orders_info = Db::table('orders')->where(['order_no'=>$order])->find();
        if($orders_info && !empty($orders_info)){
            echo $this->response(['code'=>1019,'Ret'=>'2']);exit;
        }
    }

    private function checkPayBucode($param)
    {
        $data['member_id'] = $param['RootID'];
        $data['pay_type'] = $param['PaymentMethod'];
        $data['currency_type'] = $param['PaymentCurrency'] ?? 1;
        $data['amount'] = $param['Amount'];
        $data['WebType'] = $param['WebType'] ?? 0;
        $data['PhoneOS'] = $param['PhoneOS'] ?? 0;
        $data['mac'] = $param['Device'] ?? 0;

        if (isset($param['MerchantSerialNos']) && !empty($param['MerchantSerialNos'])) {
            $data['MajorKey'] = $param['MerchantSerialNos'];
            $mk = explode(',', $data['MajorKey']);
            $model = Db::table('online_deposit')
                ->where(['serial_no' => ['in', $mk], 'member_id' => $data['member_id'], 'a.status' => 1, 'pay_status' => 1]);
        } else {
            $model = Db::table('online_deposit')
                ->where(['member_id' => $data['member_id'], 'a.status' => 1, 'pay_status' => 1]);
        }

        $deposit = $model->alias('a')->join('online_deposit_pay_type_list b', "a.id = b.online_deposit_id")
            ->where(['b.pay_type_id' => $data['pay_type'], 'b.status' => 1, 'support_devices' => $data['mac']])
            ->field(['a.*', 'b.pay_limit', 'b.day_total_amount_limit', 'b.day_total_time_limit'])
            ->find();

        if (!$deposit) {
            $MerchantSerialNos = isset($param['MerchantSerialNos'])?$param['MerchantSerialNos']:'';
            writelog('checkPayBucode_error',"online_deposit_pay_type_list 数据不存在，pay_type_id:{$data['pay_type']}, ".
                "member_id:{$data['member_id']}, support_devices:{$data['mac']},MerchantSerialNos:{$MerchantSerialNos}");
            echo $this->response(['Ret' => '2', 'code' => '1010']);
            exit;
        }

        //获取币种支持
        if($data['currency_type'] != $deposit['currency_type']){
            echo $this->response(['Ret' => '2', 'code' => '2005']);
            exit;
        }

        //新增改版修改判断限额
        if (!$this->checkLimitAmount($data['amount'], $deposit['pay_limit'])){
            writelog('newCheckPayBucode', $deposit['id'].',超过限额，'.$data['amount'].'||'.$deposit['pay_limit']);
            echo $this->response(['Ret' => '2', 'code' => '2006']);
            exit;
        }

        $res = Db::table('orders')->where(['online_deposit_id' => $deposit['id'], 'pay_status' => 1, 'pay_type_id' => $param['PaymentMethod']])
            ->whereTime('pay_time', '>=', date("Y-m-d"))
            ->whereTime('pay_time', '<', date("Y-m-d", strtotime('+1 day')))
            ->field(['ifnull(sum(amount),0) total_amount', 'count(1) total_time'])
            ->find();

        //新增改版修改判断单日总额
        if ($deposit['day_total_amount_limit'] != -1 && $res['total_amount'] + $data['amount'] > $deposit['day_total_amount_limit']){
            writelog('newCheckPayBucode',
                $deposit['id'].",超过单日总限额({$deposit['day_total_amount_limit']})：{$res['total_amount']} + {$data['amount']}");
            echo $this->response(['Ret' => '2', 'code' => '2003']);
            exit;
        }

        //新增改版修改判断单日总次数
        if ($deposit['day_total_time_limit'] != -1 && $res['total_time'] >= $deposit['day_total_time_limit']){
            writelog('newCheckPayBucode',
                "超过单日总次数({$deposit['day_total_time_limit']}):{$res['total_time']} + 1");
            echo $this->response(['Ret' => '2', 'code' => '2004']);
            exit;
        }

        return $deposit;
    }

    /*
     *检测存款商户号
     */
    private function checkPayBucode_old($param)
    {
        $data['member_id'] = $param['RootID'];
        $data['pay_type'] = $param['PaymentMethod'];
        $data['currency_type'] = $param['PaymentCurrency'] ?? 1;
        $data['amount'] = $param['Amount'];
        $data['WebType'] = $param['WebType'] ?? 0;
        $data['PhoneOS'] = $param['PhoneOS'] ?? 0;
        $data['mac'] = $param['Device'] ?? 0;
        if (isset($param['MerchantSerialNos']) && !empty($param['MerchantSerialNos'])) {
            $data['MajorKey'] = $param['MerchantSerialNos'];
            $mk = explode(',', $data['MajorKey']);
            $online_deposit_info = Db::table('online_deposit')->where(['serial_no' => ['in', $mk], 'member_id' => $data['member_id'], 'status' => 1, 'pay_status' => 1])->select();
        } else {
            $online_deposit_info = Db::table('online_deposit')->where(['member_id' => $data['member_id'], 'status' => 1, 'pay_status' => 1])->select();
        }

        if (!$online_deposit_info) {
            echo $this->response(['Ret' => '2', 'code' => '1010']);
            exit;
        }

        foreach ($online_deposit_info as $key=>$val){
            //如果支付方式不支持
            if(!in_array($data['pay_type'], explode(",",$val['bank_type']))){
                unset($online_deposit_info[$key]);
                continue;
            }
            //获取币种支持
            if($data['currency_type'] != $val['currency_type']){
                unset($online_deposit_info[$key]);
                continue;
            }

            //todo 新增判断 SupportDevices
            $pay_limit = json_decode($val['pay_limit_json'], true);
            if (empty($pay_limit)){
                writelog('newCheckPayBucode', 'pay_limit_json 数据不存在');
                unset($online_deposit_info[$key]);
                continue;
            }

            $pay_type_limit = [];
            foreach ($pay_limit as $plv){
                if ($plv['PayTypeId'] == $data['pay_type']){
                    $pay_type_limit = $plv;
                }
            }

            if (empty($pay_type_limit)){
                writelog('newCheckPayBucode', 'pay_limit_json 对应支付方式数据不存在');
                unset($online_deposit_info[$key]);
                continue;
            }

            if (!isset($pay_type_limit['SupportDevices'])){
                writelog('newCheckPayBucode', 'pay_limit_json 参数不存在：SupportDevices');
                unset($online_deposit_info[$key]);
                continue;
            }

            if (!in_array($data['mac'], explode(',', $pay_type_limit['SupportDevices']))){
                writelog('newCheckPayBucode', 'pay_limit_json 设备类型不支持');
                unset($online_deposit_info[$key]);
                continue;
            }

            $merchantt_result = Db::table('merchant')->where(['id'=>$val['merchant_id'],'status'=>1])->find();
            if($merchantt_result && !empty($merchantt_result)){
                if($merchantt_result['support']==3){
                    unset($online_deposit_info[$key]);
                    continue;
                }
                //判断是否手机IOS登入且是https
                if($data['mac']==1 && $data['PhoneOS']==1 && $data['WebType']==2){
                    if(!empty($merchantt_result['is_https']) && $merchantt_result['is_https']==1){
                        unset($online_deposit_info[$key]);
                        continue;
                    }
                }
            }else{
                unset($online_deposit_info[$key]);
                continue;
            }

            //todo 新增改版修改判断限额
            if (!$this->checkLimitAmount($data['amount'], $pay_type_limit['LimitAmount'])){
                writelog('newCheckPayBucode', '超过限额，'.$data['amount'].'||'.$pay_type_limit['LimitAmount']);
                unset($online_deposit_info[$key]);
                continue;
            }

            $res = Db::table('orders')->where(['online_deposit_id' => $val['id'], 'pay_status' => 1, 'pay_type_id' => $param['PaymentMethod']])
                ->whereTime('pay_time', '>=', date("Y-m-d"))
                ->whereTime('pay_time', '<', date("Y-m-d", strtotime('+1 day')))
                ->field(['sum(amount) total_amount', 'count(1) total_time'])
                ->find();

            //todo 新增改版修改判断单日总额
            if ($pay_type_limit['DayTotalAmountLimit'] != -1 && $res['total_amount'] + $data['amount'] > $pay_type_limit['DayTotalAmountLimit']){
                writelog('newCheckPayBucode', "超过单日总限额({$pay_type_limit['DayTotalAmountLimit']})：{$res['total_amount']} + {$data['amount']}");
                unset($online_deposit_info[$key]);
                continue;
            }

            //todo 新增改版修改判断单日总次数
            if ($pay_type_limit['DayTotalTimesLimit'] != -1 && $res['total_time'] >= $pay_type_limit['DayTotalTimesLimit']){
                writelog('newCheckPayBucode', "超过单日总次数({$pay_type_limit['DayTotalTimesLimit']}):{$res['total_time']} + 1");
                unset($online_deposit_info[$key]);
                continue;
            }

            //如果支付方式失败次数太多
            /*$can_pay_key = RedisCache::hGet($this->pay_type[$data['pay_type']],'online_deposit_'.$val['id']);
            if($can_pay_key && !empty($can_pay_key)){
                if($can_pay_key>3){
                    unset($online_deposit_info[$key]);
                    continue;
                }
            }*/
        }
        if(empty($online_deposit_info)){
            echo $this->response(['Ret'=>'1','code'=> '1011']);exit;
        }
        shuffle($online_deposit_info);
        $deposit = $online_deposit_info[rand(0,(count($online_deposit_info)-1))];
        if(empty($deposit)){
            echo $this->response(['Ret'=>'1','code'=> '1011']);exit;
        }
        return $deposit;
    }
    /**
     * 检查限额
     */
    private function checkLimitAmount($amount,$data){
        if(preg_match('/-/',$data)){
            $limit_amount = explode("-",$data);
            if(is_array($limit_amount)){
                $limit_amount_count = count($limit_amount);
                if($amount > $limit_amount[$limit_amount_count-1] || $amount < $limit_amount[0]){
                    return false;
                }
            }
        }else{
            if(!in_array($amount, explode(",",$data))){
                return false;
            }
        }
        return true;
    }
    /*
     *检测取款商户号
     */
    private function checkRefundBucode($param)
    {
        $data['member_id'] = $param['RootID'];
        $data['amount'] = $param['Amount'];
        $data['currency_type'] = $param['PaymentCurrency'] ?? 1;
        $data['pay_type'] = $param['OnlinePayType'];
        if (isset($param['MerchantSerialNos']) && !empty($param['MerchantSerialNos'])) {
            $data['MajorKey'] = $param['MerchantSerialNos'];
            $mk = explode(',', $data['MajorKey']);
            $online_deposit_info = Db::table('online_deposit')->where(['serial_no' => ['in', $mk], 'member_id' => $data['member_id'], 'status' => 1, 'refund_status' => 1])->select();
        } else {
            $online_deposit_info = Db::table('online_deposit')->where(['member_id' => $data['member_id'], 'status' => 1, 'refund_status' => 1])->select();
        }
        if (!$online_deposit_info) {
            echo $this->response(['Ret' => '2', 'code' => '1010']);
            exit;
        }
        $support_array = [];
        foreach ($online_deposit_info as $key=>$val){
            //获取币种支持
            if($data['currency_type'] != $val['currency_type']){
                unset($online_deposit_info[$key]);
                continue;
            }
            if($data['pay_type']==1){//网银通道
                $support_array = [1,4];
            }elseif ($data['pay_type']==2){//数字货币通道
                $support_array = [1,2,3];
            }
            $merchantt_result = Db::table('merchant')->where(['id'=>$val['merchant_id'],'status'=>1,'support'=>['in',$support_array]])->find();
            if($merchantt_result && !empty($merchantt_result)){
                unset($online_deposit_info[$key]);
                continue;
            }
            //如果代付失败次数太多
            /*$can_pay_key = RedisCache::hGet('online_deposit_refund',$val['id']);
            if($can_pay_key && !empty($can_pay_key)){
                if($can_pay_key>3){
                    unset($online_deposit_info[$key]);
                    continue;
                }
            }*/
        }
        if(empty($online_deposit_info)){
            echo $this->response(['Ret'=>'2','code'=> '1011']);exit;
        }
        shuffle($online_deposit_info);
        $deposit = $online_deposit_info[rand(0,(count($online_deposit_info)-1))];
        if(empty($deposit)){
            echo $this->response(['Ret'=>'2','code'=> '1011']);exit;
        }
        return $deposit;
    }

//检测金流商是否支持此存款取款功能
    private function checkMerchantt($deposit,$array)
    {
        $merchantt_info = Db::table('merchant')->where(['id'=>$deposit['merchant_id'],'status'=>1,'support'=>['in',$array]])->find();
        if(!$merchantt_info){
            echo $this->response(['Ret'=>'2','code'=> '1010']);exit;
        }
        return $merchantt_info;
    }

//检测开启网银显示页面
    private function checkBankpage($param)
    {
        $bank_data = $this->myCryptAES->encrypt($param);
        $bankpo = bankPo(config('conf._SERVERIP')."Rambopay/pay",$bank_data);
        if(!$bankpo){
            echo $this->response(['Ret'=>'2','code'=> '293']);exit;
        }
        echo $this->response(['Ret' => 0, 'Type' => 2, 'Message' => '', 'Data' => $bankpo]);
        exit;
    }
    //将图片转成base64二进制
    private function base64EncodeImage ($image_file) {
        $base64_image = '';
        $image_file = QRCODE_PATH.trim(strrchr($image_file, '/'),'/');
        $image_info = getimagesize($image_file);
        $image_response = fopen($image_file, 'r');
        $image_data = fread($image_response, filesize($image_file));
        $base64_image = 'data:' . $image_info['mime'] . ';base64,' . chunk_split(base64_encode($image_data));
        fclose($image_response);
        return $base64_image;
    }

    public function bankList(){
        $currency = $this->param['PaymentCurrency'];
        $mechant_id = $this->param['MerchantId'];

        if (!$currency){
            echo $this->response(['Ret' => 1, 'code' => 295]);exit;
        }

        if($mechant_id){
            $sql = "select b.id BankId, b.bank_code BankCode, b.bank_name BankName from merchant_bank a 
                join bank_list b on a.bank_id = b.id
                where b.currency_id = ? and a.merchant_id = ? and a.status = 1 and b.status = 1";
            $list = Db::query($sql, [$currency, $mechant_id]);
        }else{
            $sql = "select id BankId, bank_code BankCode, bank_name BankName from bank_list where currency_id = ? and status = 1";
            $list = Db::query($sql, [$currency]);
        }

        echo $this->response(['Ret' => 0, 'code' => 200, 'BankList' => $list]);exit;
    }


}
