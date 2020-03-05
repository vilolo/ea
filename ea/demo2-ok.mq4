#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- input parameters
input int      ma1=5;
input int      ma2=10;
input int      ma3=28;

#define MAGICMA  20131111

const int kpool = 80;
const double Lots = 0.01;

void OnTick()
{
    if(Period() != 60) return;

    int ordersTotal = OrdersTotal();
    int openType = 0;
    int closeType = 0;

    if(ordersTotal == 0){ //判断开单
        openType = checkOpenType2();
    }else{
        closeType = checkCloseType(ordersTotal);
    }

    for(int cnt=0;cnt<ordersTotal;cnt++)
    {
        if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
            continue;

        if(OrderType()==OP_BUY){
            if(
                closeType == CLOSE_BUY || closeType == CLOSE_BUY_AND_OPEN_SELL
                || OrderOpenPrice()+25<Ask  // 止盈
                //|| OrderOpenPrice()-10>Bid  //止损
            ){  //平多
                if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Violet)){
                    Print("OrderClose buy error ",GetLastError());
                }
                if(closeType == CLOSE_BUY_AND_OPEN_SELL) openType = DOWN_3_SAME;
            }
        }else{
            if(
                closeType == CLOSE_SELL || closeType == CLOSE_SELL_AND_OPEN_BUY
                || OrderOpenPrice()-25>Bid  // 止盈
                //|| OrderOpenPrice()+10<Ask  //止损
            ){  //平空
                if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Violet)){
                    Print("OrderClose sell error ",GetLastError());
                }
                if(closeType == CLOSE_SELL_AND_OPEN_BUY) openType = UP_3_SAME;
            }
        }


        // if(closeType > 0){
        //     if(closeType == CLOSE_BUY || closeType == CLOSE_BUY_AND_OPEN_SELL){  //平多
        //         if(OrderType()==OP_BUY){
        //             if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Violet)){
        //                 Print("OrderClose buy error ",GetLastError());
        //             }
        //             if(closeType == CLOSE_BUY_AND_OPEN_SELL) openType = DOWN_3_SAME;
        //         }
        //     }else{
        //         if(OrderType()==OP_SELL){
        //             if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Violet)){
        //                 Print("OrderClose sell error ",GetLastError());
        //             }
        //             if(closeType == CLOSE_SELL_AND_OPEN_BUY) openType = UP_3_SAME;
        //         }
        //     }
        // }
    }

    if(openType > 0){
        int ticket;
        if(
            openType==UP_3_SAME ||
            openType==UP_3_DIFF ||  
            openType==UP_2
        ){  //openBuy
            ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,3,0,0,"open buy:"+TimeCurrent(),MAGICMA,0,Red);
            if(ticket>0)
            {
                if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
                Print("BUY order opened : ",OrderOpenPrice());
            }else{
                Print("Error opening BUY order : ",GetLastError());
            }
        }else{  //openSell
            ticket=OrderSend(Symbol(),OP_SELL,Lots,Bid,3,0,0,"open sell:"+TimeCurrent(),MAGICMA,0,Lime);
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

const int UP_3_SAME = 1;
const int UP_3_DIFF = 2;
const int DOWN_3_SAME = 3;
const int DOWN_3_DIFF = 4;
const int UP_2 = 5;
const int DOWN_2 = 6;
int checkOpenType(){
    int type = 0;

    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,2);
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,2);

    if(
        (pre1Ma1-pre1Ma3>0) != (pre2Ma1-pre2Ma3>0)
    ){
        if(pre1Ma1>pre1Ma3){    //上叉
            if(pre1Ma1 > pre2Ma1){  //同向
                type = UP_3_SAME;
            }else{
                type = UP_3_DIFF;
            }
        }else{  //下叉
            if(pre1Ma1 < pre2Ma1){  //同向
                type = DOWN_3_SAME;
            }else{
                type = DOWN_3_DIFF;
            }
        }
    }

    return type;
}

int checkOpenType2(){
    int type = 0;

    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,2);
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,2);

    //1和3
    if(
        (pre1Ma1-pre1Ma3>0) != (pre2Ma1-pre2Ma3>0) &&   //叉
        (pre1Ma1-pre1Ma3>0) == (pre1Ma1-pre2Ma1>0) &&    //1同向
        (pre1Ma1-pre2Ma1>0) == (pre1Ma3-pre2Ma3>0)  //3同向
    ){
        if(pre1Ma1>pre1Ma3){    //上叉
            type = UP_3_SAME;
        }else{  //下叉
            type = DOWN_3_SAME;
        }
    }else{  //1和2
        if(
            (pre1Ma1-pre1Ma2>0) != (pre2Ma1-pre2Ma2>0) &&   //叉
            (fabs(pre2Ma1-pre2Ma3)>5)
        ){
            if(pre1Ma1>pre1Ma2){    //上叉
                type = UP_2;
            }else{
                type = DOWN_2;
            }
        }
    }

    return type;
}

const int CLOSE_BUY = 1;
const int CLOSE_BUY_AND_OPEN_SELL = 2;
const int CLOSE_SELL = 11;
const int CLOSE_SELL_AND_OPEN_BUY = 12;
int checkCloseType(int ordersTotal){
    int type = 0;

    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,2);
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,2);

    if(
        (pre1Ma1-pre1Ma3>0) != (pre2Ma1-pre2Ma3>0)
    ){
        if(pre1Ma1>pre1Ma3){    //上叉
            type = CLOSE_SELL_AND_OPEN_BUY;
            // if(pre1Ma1 > pre2Ma1){  //同向
            //     type = CLOSE_SELL;
            // }else{
            //     //type = UP_3_DIFF;
            // }
        }else{  //下叉
            type = CLOSE_BUY_AND_OPEN_SELL;
            // if(pre1Ma1 < pre2Ma1){  //同向
            //     type = CLOSE_BUY;
            // }else{
            //     //type = DOWN_3_DIFF;
            // }
        }
    }

    return type;
}

int checkCloseType2(int ordersTotal){
    int type = 0;

    return type;
}

int OnInit()
{
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}