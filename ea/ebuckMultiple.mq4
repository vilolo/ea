#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input int      isMultiple=1;  //非1=单订单，1=多订单

//============ strategy init ================

//============ strategy init end ============

#define MAGICMA  20200309

const double Lots = 0.01;

//close
#define CLOSE_BUY 1
#define CLOSE_SELL 2

//open
#define OPEN_BUY 1
#define OPEN_SELL 2

void OnTick()
{
    //check close
    //check Stop profit or loss
    //check open

    int ticket;
    int openType = 0;
    int closeType = 0;
    string ttag = TimeCurrent()-(TimeCurrent()%3600);
    bool isOpenThisK = false;   //判断当前K不重复开单

    openType = openStrategy();

    int ordersTotal = OrdersTotal();
    if(ordersTotal>0){
        closeType = closeStrategy(openType);

        for(int cnt=0;cnt<ordersTotal;cnt++){
            if(
                !OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES) ||
                OrderMagicNumber() != MAGICMA
            )
                continue;
            
            if(OrderType() == OP_BUY){
                if(closeType == CLOSE_BUY || StopStrategy() == CLOSE_BUY){
                    //todo close buy
                    if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Violet)){
                        Print("OrderClose buy error ",GetLastError());
                    }
                    continue;
                }
            }

            if(OrderType() == OP_SELL){
                if(closeType == CLOSE_SELL || StopStrategy() == CLOSE_SELL){
                    //todo close sell
                    if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Violet)){
                        Print("OrderClose sell error ",GetLastError());
                    }
                    continue;
                }
            }

            if(!isOpenThisK && OrderComment() == ttag){
                isOpenThisK = true;
            }
        }
    }

    if(!isOpenThisK && (isMultiple == 1 || ordersTotal == 0)){
        if(openType>0){
            if(openType == OPEN_BUY){
                //todo open buy
                ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,3,0,0, ttag, MAGICMA,0,Red);
                if(ticket>0)
                {
                    if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
                    Print("BUY order opened : ",OrderOpenPrice());
                }else{
                    Print("Error opening BUY order : ",GetLastError());
                }
            }else{
                //todo open sell
                ticket=OrderSend(Symbol(),OP_SELL,Lots,Bid,3,0,0, ttag, MAGICMA,0,Lime);
                if(ticket>0)
                {
                    if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
                    Print("SELL order opened : ",OrderOpenPrice());
                }else{
                    Print("Error opening SELL order : ",GetLastError());
                }
            }
        }
    }
}

//=================== strategy 1 ================
int closeStrategy1(int openType){
    return 0;
}

input int profitPoint = 20; 
input int lossPoint = 9;
int StopStrategy(){
    //return 0;
    if(OrderType() == OP_BUY){
        if(OrderOpenPrice()+profitPoint<Ask){    //止盈
            //return CLOSE_BUY;
        }
        if(OrderOpenPrice()-lossPoint>Bid){    //止损
            return CLOSE_BUY;
        }
    }
    if(OrderType() == OP_SELL){
        if(OrderOpenPrice()-profitPoint>Bid){    //止盈
            //return CLOSE_SELL;
        }
        if(OrderOpenPrice()+lossPoint<Ask){    //止损
            return CLOSE_SELL;
        }
    }

    return 0;
}

//--- input parameters
// input int      ma1=6;
// input int      ma2=13;
// input int      ma3=25;

double    offsetStd=0.005;   //互相抵消的临界值    0.005 or 0.018
double    slopeStd=2;

int openStrategy1(){
    int pi = 1;
    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre3Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi+2);
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi+2);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre3Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi+2);

    int type = 0;

    if(
        (pre1Ma2-pre1Ma3>0) != (pre2Ma2-pre2Ma3>0)  //2叉3
    ){
        if(pre1Ma2>pre1Ma3){    //上叉
            type = OPEN_BUY;
            
        }else{  //下叉
            type = OPEN_SELL;
        }

        //=== 小过滤 ===
        //2变化幅度大于3变化幅度
        if(
            type != 0 &&
            fabs(pre1Ma2-pre2Ma2) < fabs(pre1Ma3-pre2Ma3)
        ){
            type = 0;
        }

        //23斜率互抵
        if(
            type != 0 &&
            (pre1Ma2-pre2Ma2>0) != (pre1Ma3-pre2Ma3>0)
            && fabs( pre1Ma2-pre2Ma2 + pre1Ma3-pre2Ma3 )<offsetStd
        ){
            type = 0;
        }

    }else{
        if(
            (pre1Ma1-pre1Ma2>0) != (pre2Ma1-pre2Ma2>0)  //1叉2
        ){
            //判断是否保留
            bool isRatian = true;

            if(isRatian &&
                (pre1Ma1-pre2Ma1>0) != (pre1Ma2-pre2Ma2>0)
            ){
                isRatian = false;
            }

            double p1Ma12 = pre1Ma1-pre1Ma2;
            double p2Ma12 = pre2Ma1-pre2Ma2;
            double p3Ma12 = pre3Ma1-pre3Ma2;

            if(isRatian &&
                fabs((p1Ma12-p2Ma12)-(p2Ma12-p3Ma12)) < slopeStd
            ){
                isRatian = false;
            }else{
                if(fabs(p1Ma12) > fabs(p2Ma12)){    //放大

                }else{  //缩小
                    if(fabs(pre1Ma1-pre1Ma3)<2){
                        //isRatian = false;
                    }
                }
            }

            if(isRatian){
                if(pre1Ma1>pre1Ma2){    //上叉
                    type = OPEN_BUY;
                    
                }else{  //下叉
                    type = OPEN_SELL;
                }
            }
        }
    }

    return type;
}

int unduePrice = 5;
int openStrategy2(){
    int pi = 1;
    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre3Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi+2);
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi+2);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre3Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi+2);
    
    int type = 0;

    if(
        (pre1Ma2-pre1Ma3>0) != (pre2Ma2-pre2Ma3>0)  //2叉3
    ){
        if(pre1Ma2 > pre1Ma3){
            type = OPEN_BUY;
        }else{
            type = OPEN_SELL;
        }
    }else{  //补充横盘情况，用1叉2或斜率

    }

    //=== 小过滤 ===
    //2变化幅度大于3变化幅度
    if(
        type != 0 &&
        fabs(pre1Ma2-pre2Ma2) < fabs(pre1Ma3-pre2Ma3)
    ){
        type = 0;
    }

    //23斜率互抵
    if(
        type != 0 &&
        (pre1Ma2-pre2Ma2>0) != (pre1Ma3-pre2Ma3>0)
        && fabs( pre1Ma2-pre2Ma2 + pre1Ma3-pre2Ma3 )<offsetStd
    ){
        type = 0;
    }

    //看到时已经过猛了
    if(
        fabs(Close[1]-pre1Ma3) > unduePrice
    ){
        type = 0;
    }
    
    return type;
}

int closeStrategy2(int openType){
    if(openType != 0){
       if(openType == OPEN_BUY){
         return CLOSE_SELL;
       }else{
         return CLOSE_BUY;
       }
    }else{

    }

    return 0;
}

//======================== 3 按步骤 restart ============================

// input int      ma1=6;
// input int      ma2=13;
// input int      ma3=25;

int openStrategy3(){
    int pi = 1;
    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre3Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi+2);
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi+2);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre3Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi+2);

    int type = 0;

    if(
        (pre1Ma2-pre1Ma3>0) != (pre2Ma2-pre2Ma3>0)  //2叉3
    ){
        if(pre1Ma2 > pre1Ma3){
            type = OPEN_BUY;
        }else{
            type = OPEN_SELL;
        }
    }

    return type;
}

int threshold = 5; //阈值
double leadWireRatio = 0.6;
int closeStrategy3(int openType){
    int type = 0;
    
    if(openType != 0){
       if(openType == OPEN_BUY){
         type = CLOSE_SELL;
       }else{
         type = CLOSE_BUY;
       }
    }

    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
    
    //判断行情尽头遇阻，上下引线判断
    if(type == 0){
        if(pre1Ma2>pre1Ma3 && High[1]-Low[1]>threshold
            && (High[1]-Close[1])/(High[1]-Low[1])>leadWireRatio  //上影线大于开盘到最低的某个比例
        ){
            type = CLOSE_BUY;
        }

        if(pre1Ma2<pre1Ma3 && High[1]-Low[1]>threshold
            && (Close[1]-Low[1])/(High[1]-Low[1])>leadWireRatio  //上影线大于开盘到最低的某个比例
        ){
            type = CLOSE_SELL;
        }
    }

    //连续3根k线与k线顺序不一致
    if(type == 0){
        if(pre1Ma2>pre1Ma3
            && Close[1]<pre1Ma3 && Close[2]<pre1Ma3 && Close[3]<pre1Ma3
        ){
            //type = CLOSE_BUY;
        }

        if(pre1Ma2<pre1Ma3
            && Close[1]>pre1Ma3 && Close[2]>pre1Ma3 && Close[3]>pre1Ma3
        ){
            //type = CLOSE_SELL;
        }
    }

    //判断行情突然断崖
    if(type == 0){
        if(pre1Ma2>pre1Ma3){

        }
    }

    return type;
}

//========================== 4 用k线加均线开单 ==================================

//== 两均线+三K线 ==
//看K线收盘和两均线的位置关系
//1.慢，快，k       海底月 -> 升海日
//2.慢，k，快       黎明前 海日
//3.k，快慢or慢快   初阳 -> 午日
//4.k，快，慢       午日
//5.快，k，慢       落日前 云阳
//6.快慢or慢快,k    初月
//7.慢，快，k       沉海月 -> 海底月

//=== open ===
//buy：海日，初阳
//sell：云阳，初月

//=== close ===
//buy：午日，云阳       止损：初月，沉海月，海底月
//sell：海底月，海日    止损：初阳，升阳，午阳

input int      ma1=6;
input int      ma2=13;
input int      ma3=25;

int openStrategy(){
    int type = 0;
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,3);
    double pre4Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,4);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,2);
    double pre3Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,3);
    double pre4Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,4);

    //海日
    if(
        pre2Ma2<pre2Ma3
        && pre1Ma2>pre1Ma3 //上叉
        && Close[1]>pre1Ma3   //大于3均线
        && (pre1Ma2-pre2Ma2)>fabs(pre1Ma3-pre2Ma3) //2斜率大于3并且为上钩
        && High[1]-pre1Ma2<6  //交叉处K线不能涨得太高
        //&& (High[1]-Open[1])>(High[2]-Open[2])/2   //k线的正走向不能小于前一根正走向的一半
        //&& (Open[1]-Low[1])<(Open[2]-Low[2])
    ){
        type = OPEN_BUY;
    }

    return type;
}

int closeStrategy(int openType){
    int type = 0;

    if(openType != 0){
       if(openType == OPEN_BUY){
         type = CLOSE_SELL;
       }else{
         type = CLOSE_BUY;
       }
    }

    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,3);
    double pre4Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,4);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,2);
    double pre3Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,3);
    double pre4Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,4);

    //云日
    if(type == 0 &&
        pre2Ma2>pre2Ma3 &&
        pre1Ma2<pre1Ma3
    ){
        type = CLOSE_BUY;
    }

    return type;
}