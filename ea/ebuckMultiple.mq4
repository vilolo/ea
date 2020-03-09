#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- input parameters
input int      ma1=5;
input int      ma2=10;
input int      ma3=28;

input int      isMultiple=0;  //非1=单订单，1=多订单

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
    bool isOpenThisHour = false;

    int ordersTotal = OrdersTotal();
    if(ordersTotal>0){
        closeType = closeStrategy();

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

            if(!isOpenThisHour && OrderComment() == ttag){
                printf("==============:"+ttag);
                isOpenThisHour = true;
            }
        }
    }

    if(!isOpenThisHour && (isMultiple == 1 || ordersTotal == 0)){
        openType = openStrategy();
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
int closeStrategy(){
    return 0;
}

int StopStrategy(){
    if(OrderType() == OP_BUY){
        if(OrderOpenPrice()+10<Ask){    //止盈
            return CLOSE_BUY;
        }
        if(OrderOpenPrice()-5>Bid){    //止损
            return CLOSE_BUY;
        }
    }
    if(OrderType() == OP_SELL){
        if(OrderOpenPrice()-10>Bid){    //止盈
            return CLOSE_SELL;
        }
        if(OrderOpenPrice()+5<Ask){    //止损
            return CLOSE_SELL;
        }
    }

    return 0;
}

int openStrategy(){
    int type = 0;

    int pi = 1;
    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,pi+1);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,pi+1);

    if(
        (pre1Ma1-pre1Ma3>0) != (pre2Ma1-pre2Ma3>0)
    ){
        if(pre1Ma1>pre1Ma3){    //上叉
            type = OPEN_BUY;
            
        }else{  //下叉
            type = OPEN_SELL;
        }
    }

    return type;
}