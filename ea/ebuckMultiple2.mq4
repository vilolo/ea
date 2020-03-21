#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define MAGICMA  20200321
const double Lots = 0.01;
int   isMultiple=1;

#define OOPEN_BUY 1
#define OOPEN_SELL 2
#define CLOSE_BUY 11
#define CLOSE_SELL 12

int      ma2=16;

void OnTick()
{
    //check open type

    //loop order
        //check if need close by open type
        //if not check if need close by close strategy
        //if not check if need stop by profit or loss
        //check if has opened in this hour
    
    //do operation by open or close type

    bool isOpenThisK = false;
    string ttag = TimeCurrent()-(TimeCurrent()%3600);
    int ticket;
    int openType=0;
    int closeType=0;

    openType = openStrategy();

    int ordersTotal = OrdersTotal();
    if(ordersTotal>0){
        for(int cnt=0;cnt<ordersTotal;cnt++){
            if(
                !OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES) ||
                OrderMagicNumber() != MAGICMA
            )
                continue;

            if(OrderType() == OP_BUY){
                if(closeStrategy(openType) == CLOSE_BUY || stopStrategy() == CLOSE_BUY){
                    //todo close buy
                    if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Violet)){
                        Print("OrderClose buy error ",GetLastError());
                    }
                    continue;
                }
            }

            if(OrderType() == OP_SELL){
                if(closeStrategy(openType) == CLOSE_SELL || stopStrategy() == CLOSE_SELL){
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
            
            if(openType == OOPEN_BUY){
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

input int profitPoint = 20; 
input int lossPoint = 10;
int stopStrategy(){
    int type = 0;

    if(OrderType() == OP_BUY){
        if(OrderOpenPrice()+profitPoint<Ask){    //止盈
            type = CLOSE_BUY;
        }
        if(OrderOpenPrice()-lossPoint>Bid){    //止损
            type = CLOSE_BUY;
        }
    }else if(OrderType() == OP_SELL){
        if(OrderOpenPrice()-profitPoint>Bid){    //止盈
            type = CLOSE_SELL;
        }
        if(OrderOpenPrice()+lossPoint<Ask){    //止损
            type = CLOSE_SELL;
        }
    }

    return type;
}

int openStrategy(int i=0){
    int type = 0;

    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+3);

    if(
        pre1Ma2<Close[i+1]
        && pre2Ma2>Close[i+2]
        && pre3Ma2>Close[i+3]
    ){
        type = OOPEN_BUY;
    }

    return type;
}

int closeStrategy(int openType){
    int type = 0;

    if(openType == OOPEN_BUY){
        type = CLOSE_SELL;
    }

    if(openType == OOPEN_SELL){
        type = CLOSE_BUY;
    }

    return type;
}