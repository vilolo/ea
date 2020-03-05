#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- input parameters
input int      ma1=5;
input int      ma2=10;
input int      ma3=28;

//============ strategy init ================
#define UP_13_UU 1  //up 1叉3，两个up
#define UP_13_UD 2  //up 1叉3，1up,3down
#define UP_13_DD 3  //up 1叉3，1down,3down

#define UP_12_UU 4
#define UP_12_UD 5
#define UP_12_DD 6
#define OPEN_BUY_AFTER_CLOSE 7

#define DOWN_13_UU 11
#define DOWN_13_DU 12
#define DOWN_13_DD 13

#define DOWN_12_UU 14
#define DOWN_12_DU 15
#define DOWN_12_DD 16
#define OPEN_SELL_AFTER_CLOSE 17

#define CLOSE_BUY 1
#define CLOSE_BUY_OPEN 2
#define CLOSE_SELL 11
#define CLOSE_SELL_OPEN 12
//============= strategy init end ==========

#define MAGICMA  20200305

const double Lots = 0.01;

void OnTick()
{
    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,2);
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,2);

    int closeType = 0;
    int openType = 0;
    int ordersTotal = OrdersTotal();
    int ticket;
    if(ordersTotal == 0){ //判断开单
        openType = strategyOpen1(0,
            pre1Ma1,pre2Ma1,pre1Ma2,pre2Ma2,pre1Ma3,pre2Ma3);

    }else{
        closeType = strategyClose1(0,
                pre1Ma1,pre2Ma1,pre1Ma2,pre2Ma2,pre1Ma3,pre2Ma3);
                
        if(closeType > 0){
            if(closeType == CLOSE_BUY_OPEN){
                openType = OPEN_SELL_AFTER_CLOSE;
            }
            if(closeType == CLOSE_SELL_OPEN){
                openType = OPEN_BUY_AFTER_CLOSE;
            }
        }
        
        for(int cnt=0;cnt<ordersTotal;cnt++)
        {
            if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
            continue;

            if(closeType > 0){
                if(closeType<10){   //close buy
                    if(OrderType()==OP_BUY){
                        if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Violet)){
                            Print("OrderClose buy error ",GetLastError());
                        }
                        continue;
                    }
                }else{  //close sell
                    if(OrderType()==OP_SELL){
                        if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Violet)){
                            Print("OrderClose sell error ",GetLastError());
                        }
                        continue;
                    }
                }
            }

            //止损止盈
            //...........
        }
    }

    if(openType > 0){
        if(openType < 10){  //open buy
            ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,3,0,0, openType+"open buy:"+TimeCurrent(),MAGICMA,0,Red);
            if(ticket>0)
            {
                if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
                Print("BUY order opened : ",OrderOpenPrice());
            }else{
                Print("Error opening BUY order : ",GetLastError());
            }
        }else{
            ticket=OrderSend(Symbol(),OP_SELL,Lots,Bid,3,0,0, openType+"open sell:"+TimeCurrent(),MAGICMA,0,Lime);
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


// --------------------------------- public --------------------------------------

int strategyOpen1(int i, 
    double pre1Ma1,double pre2Ma1,double pre1Ma2,double pre2Ma2,double pre1Ma3,double pre2Ma3
){
    int type = 0;

    // int pi = 1;
    // double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
    // double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
    // double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi);
    // double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
    // double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+pi);
    // double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+pi+1);

    //当前
    if(
        (pre1Ma1-pre1Ma3>0) != (pre2Ma1-pre2Ma3>0)
    ){
        if(pre1Ma1>pre1Ma3){
            type = UP_13_UU;
        }else{
            type = DOWN_13_DD;
        }
    }

    //用历史过滤

    return type;
}

int strategyClose1(int i, 
    double pre1Ma1,double pre2Ma1,double pre1Ma2,double pre2Ma2,double pre1Ma3,double pre2Ma3
){
    int type = 0;

    if(
        fabs(pre1Ma1-pre1Ma3)>5 &&
        fabs(pre1Ma3-iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+6))<3
    ){
        if(pre1Ma1>pre1Ma3){
            type = CLOSE_BUY_OPEN;
        }else{
            type = CLOSE_SELL_OPEN;
        }
    }

    return type;
}