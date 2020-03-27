#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define MAGICMA  20200321
const double Lots = 0.01;
int   maxOrder=3;

#define OOPEN_BUY 1
#define OOPEN_SELL 2
#define CLOSE_BUY 11
#define CLOSE_SELL 12

input int ma1=8;
input int ma2=16;
input int ma3=28;

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
    
    int closeOrdersTotal = 0;
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
                    }else{
                        closeOrdersTotal++;
                    }
                    continue;
                }
            }

            if(OrderType() == OP_SELL){
                if(closeStrategy(openType) == CLOSE_SELL || stopStrategy() == CLOSE_SELL){
                    //todo close sell
                    if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Violet)){
                        Print("OrderClose sell error ",GetLastError());
                    }else{
                        closeOrdersTotal++;
                    }
                    continue;
                }
            }

            if(!isOpenThisK && OrderComment() == ttag){
                isOpenThisK = true;
            }
        }
    }

    if(!isOpenThisK && ordersTotal-closeOrdersTotal<maxOrder && openType>0){
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

int profitPoint = 10;
int lossPoint = 10;
int stopStrategy(){
    int type = 0;

    if(OrderType() == OP_BUY){
        if(OrderOpenPrice()+profitPoint<Ask){    //止盈
            //type = CLOSE_BUY;
        }
        if(OrderOpenPrice()-lossPoint>Bid){    //止损
            type = CLOSE_BUY;
        }
    }else if(OrderType() == OP_SELL){
        if(OrderOpenPrice()-profitPoint>Bid){    //止盈
            //type = CLOSE_SELL;
        }
        if(OrderOpenPrice()+lossPoint<Ask){    //止损
            type = CLOSE_SELL;
        }
    }

    return type;
}

int openStrategy1(int i=0){
    int type = 0;

    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+3);

    if(
        pre1Ma2<Close[i+1] != pre2Ma2<Close[i+2]
        && pre2Ma2<Close[i+2] == pre3Ma2<Close[i+3]
    ){
        if(pre1Ma2<Close[i+1]){
            type = OOPEN_BUY;
        }else{
            type = OOPEN_SELL;
        }
    }

    return type;
}

int kpool = 80;
int openStrategy2(int i=0){
    int type = 0;

    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+3);
    double pre4Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+4);

    if(pre1Ma2<Close[i+1] != pre2Ma2<Close[i+2]
        && pre2Ma2<Close[i+2] == pre3Ma2<Close[i+3])
    {
        double point2Price = 0;
        int point2Index;
        double point3Price = 0;
        int point3Index;
        double point4Price = 0;
        int point4Index;
    
        double curPrice = iMA(Symbol(),0,1,0,MODE_SMA,PRICE_MEDIAN,i+1);
        bool isFindMin = iMA(Symbol(),0,1,0,MODE_SMA,PRICE_MEDIAN,i+2)<curPrice;

        for(int pi=2;pi<kpool;pi++){
            double temp0Price = iMA(Symbol(),0,1,0,MODE_SMA,PRICE_MEDIAN,i+pi-1);
            double temp1Price = iMA(Symbol(),0,1,0,MODE_SMA,PRICE_MEDIAN,i+pi);
            double temp2Price = iMA(Symbol(),0,1,0,MODE_SMA,PRICE_MEDIAN,i+pi+1);
            
            if((temp2Price>temp1Price == isFindMin) && (temp1Price>temp0Price != isFindMin)){
                bool isTarget = true;
                for(int j=0;j<6;j++){
                    if(iMA(Symbol(),0,1,0,MODE_SMA,PRICE_MEDIAN,i+pi+2+j)>temp1Price != temp2Price>temp1Price){
                        isTarget = false;
                        break;
                    }
                }
                if(isTarget){
                    isFindMin = !isFindMin;
                    if(point2Price == 0){
                        point2Price = temp1Price;
                        point2Index = pi;
                    }else if(point3Price == 0){
                        point3Price = temp1Price;
                        point3Index = pi;
                    }else if(point4Price == 0){
                        point4Price = temp1Price;
                        point4Index = pi;
                        break;
                    }
                }
            }
        }

        if(point2Price<curPrice){
            type = OOPEN_BUY;
        }else{
            type = OOPEN_SELL;
        }

        //过滤条件
        if(
            point2Index > 4
            || curPrice>point2Price != point2Price>point4Price
        ){
            //type = 0;
        }
    }

    return type;
}

int openStrategy3(int i=0){
    int type = 0;

    //type = openPoint1(i);
    type = openPoint2(i);

    int ma = ma2;

    double point2Price = 0;
    int point2Index;
    double point3Price = 0;
    int point3Index;
    double point4Price = 0;
    int point4Index;
   
    double curPrice = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+1);
    bool isFindMin = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+2)<curPrice;

    for(int pi=2;pi<kpool;pi++){
        double temp0Price = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+pi-1);
        double temp1Price = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+pi);
        double temp2Price = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+pi+1);
        
        if((temp2Price>temp1Price == isFindMin) && (temp1Price>temp0Price != isFindMin)){
            bool isTarget = true;
            for(int j=0;j<6;j++){
                if(iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+pi+2+j)>temp1Price != temp2Price>temp1Price){
                    isTarget = false;
                    break;
                }
            }
            if(isTarget){
                isFindMin = !isFindMin;
                if(point2Price == 0){
                    point2Price = temp1Price;
                    point2Index = pi;
                }else if(point3Price == 0){
                    point3Price = temp1Price;
                    point3Index = pi;
                }else if(point4Price == 0){
                    point4Price = temp1Price;
                    point4Index = pi;
                    break;
                }
            }
        }
    }

    if(point2Price<point4Price){
        type = 0;
    }

    return type;
}

int openPoint1(int i){
    int type = 0;

    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+3);

    if(pre1Ma2>pre2Ma2 != pre2Ma2>pre3Ma2){
        if(pre1Ma2>pre2Ma2){    //up
            type = OOPEN_BUY;
        }else{  //down
            type = OOPEN_SELL;
        }
    }

    return type;
}

int openPoint2(int i){
    int type = 0;

    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+1);
    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+2);
    double pre3Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+3);

    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+3);

    if(
        pre1Ma1>pre1Ma2 != pre2Ma1>pre2Ma2
    ){
        if(pre1Ma2>pre2Ma2){    //up
            type = OOPEN_BUY;
        }else{  //down
            type = OOPEN_SELL;
        }
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

//================ ==================
int maPeriod = 5;   //前N周期内1未叉2
double maMaxDiff = 4;
double num_array[3];
int openStrategy(int i=0){
    int type = 0;

    //判断是波浪的延续还是风平浪静的启动,...好像直接判断两种情况是否符合更合理

    double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+1);
    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1);
    double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+1);

    double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+2);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2);
    double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+2);

    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+3);

    num_array[0] = pre1Ma1;
    num_array[1] = pre1Ma2;
    num_array[2] = pre1Ma3;
    double tempMax1 = num_array[ArrayMaximum(num_array)];
    double tempMin1 = num_array[ArrayMinimum(num_array)];

    num_array[0] = pre2Ma1;
    num_array[1] = pre2Ma2;
    num_array[2] = pre2Ma3;
    double tempMax2 = num_array[ArrayMaximum(num_array)];
    double tempMin2 = num_array[ArrayMinimum(num_array)];

    //风平浪静的启动
    if(
        ((Close[i+1]>tempMax1 && Close[i+2]<tempMax2) || (Close[i+1]<tempMin1 && Close[i+2]>tempMin2))
        && tempMax1-tempMin1 < maMaxDiff
    ){
        if(Close[i+1]>pre1Ma1){
            type = OOPEN_BUY;
        }else{
            type = OOPEN_SELL;
        }
    }

    //波浪的延续，有波浪的需要
    if(
        type == 0
        && pre1Ma1>pre1Ma2 == pre1Ma2>pre1Ma3  //正序
        && (    //ma2 k 穿过
            pre1Ma1>pre1Ma2 == Close[i+1]<pre1Ma2
            && (Close[i+1]>pre1Ma2 != Close[i+2]>pre2Ma2)
            && (Close[i+2]>pre2Ma2 == Close[i+3]>pre3Ma2)
        )
    ){
        if(pre1Ma1>pre1Ma2){
            type = OOPEN_SELL;
        }else{
            type = OOPEN_BUY;
        }

        //==== loop ====
        //前N周期内1未叉2
        bool isPass = true;
        for(int pi=2;pi<maPeriod;pi++){
            if(
                pre1Ma1>pre1Ma2 != iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi)>iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi)
            ){
                isPass = false;
                break;
            }
        }

        if(!isPass){
            type = 0;
        }
    }

    return type;
}