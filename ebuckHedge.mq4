#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define OOPEN_BUY 1
#define OOPEN_SELL 2
#define CLOSE_BUY 11
#define CLOSE_SELL 12
#define STOP_LOSS 1
#define STOP_PROFIT 2

#define MAGICMA  20200329
const double Lots = 0.01;

input int ma1=8;
input int ma2=16;
input int ma3=28;

int OnInit()
{

   return(INIT_SUCCEEDED);
}

void OnTick()
{
   //查当前订单
   //找open点
   //找close点
   //当前有订单则循环订单
      //close点符合，则平仓
      //判断是否达到止损点，达到则平仓
      //判断订单是否与open点冲突
         //冲突则判断是否超过止盈点
            //超过则平仓
      //订单与open点相同，则不开仓
      //close与open点不冲突，并且没有open点一致的单，则开单
   
   int ticket;
   int buyOrders = 0;
   int sellOrders = 0;
   
   int openType=0;
   int closeType=0;
   int stopType=0;
   
   string ttag = TimeCurrent()-(TimeCurrent()%3600);
   
   openType = openStrategy();
   closeType = closeStrategy();
   int ordersTotal = OrdersTotal();
   if(ordersTotal>0){
      for(int cnt=0;cnt<ordersTotal;cnt++){
         if(
            !OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES) ||
            OrderMagicNumber() != MAGICMA
         ) continue;
         
         stopType = stopStrategy();
         
         if(OrderType() == OP_BUY){
            if(
               //closeType == CLOSE_BUY
               (closeType == CLOSE_BUY && stopType == STOP_PROFIT)
               || stopType == STOP_LOSS
               || (openType == OOPEN_SELL && stopType == STOP_PROFIT)
            ){
               if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Violet)){
                  Print("OrderClose buy error ",GetLastError());
               }else{
                  continue;
               }
            }
            buyOrders++;
         }
         
         if(OrderType() == OP_SELL){
            if(
               //closeType == CLOSE_SELL
               (closeType == CLOSE_SELL && stopType == STOP_PROFIT)
               || stopType == STOP_LOSS
               || (openType == OOPEN_BUY && stopType == STOP_PROFIT)
            ){
               if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Violet)){
                  Print("OrderClose sell error ",GetLastError());
               }else{
                  continue;
               }
            }
            sellOrders++;
         }
      }
   }
   
   if(openType == OOPEN_BUY && closeType != CLOSE_BUY && buyOrders == 0){
      ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,3,0,0, ttag, MAGICMA,0,Red);
      if(ticket>0)
      {
         if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         Print("BUY order opened : ",OrderOpenPrice());
      }else{
         Print("Error opening BUY order : ",GetLastError());
      }
   }else if(openType == OOPEN_SELL && closeType != CLOSE_SELL && sellOrders == 0)
   {
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

//0=nothing, 1=profit, 2=loss
int profitPoint = 10;
int lossPoint = 10;
int stopStrategy(){
   int type = 0;
   if(OrderType() == OP_BUY){
      if(OrderOpenPrice()+profitPoint<Ask){    //止盈
         type = STOP_PROFIT;
      }
      if(OrderOpenPrice()-lossPoint>Bid){    //止损
         type = STOP_LOSS;
      }
   }else{
      if(OrderOpenPrice()-profitPoint>Bid){    //止盈
         type = STOP_PROFIT;
      }
      if(OrderOpenPrice()+lossPoint<Ask){    //止损
         type = STOP_LOSS;
      }
   }
   return type;
}

int openStrategy(int i=0){
   int type = 0;

   type = openFunMa12();

   //type = openFunWave();
   //type = type>0?type:openFunShoots();

   return type;
}

int openFunMa12(){   //1叉2
   int type = 0;

   double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,1);
   double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
   double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
   double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,2);
   double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
   
   if(
      pre1Ma1>pre1Ma2 == pre1Ma2>pre1Ma3
      && pre1Ma1>pre1Ma2 != pre2Ma1>pre2Ma2
   ){
      type = pre1Ma1>pre1Ma2?OOPEN_BUY:OOPEN_SELL;
   }

   return type;
}

int openFunK123(){
   int type = 0;

   double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,1);
   double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
   double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);

   if(
      Close[1]>pre1Ma1 == Open[1]<pre1Ma1
      && Close[1]>pre1Ma2 == Open[1]<pre1Ma2
      && Close[1]>pre1Ma3 == Open[1]<pre1Ma3
   ){
      type = Close[1]>pre1Ma1?OOPEN_BUY:OOPEN_SELL;
   }

   return type;
}

//commonly
int openFunWave(){   //波浪延续
   int type = 0;

   double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,1);
   double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
   double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
   double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,2);
   double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
   double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,3);
   double pre4Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,4);
   
   if(
      pre1Ma1>pre1Ma2 == pre1Ma2>pre1Ma3  //?? 5, 30, 7 不是正序，而且长期是正的，18到现在是负得最严重的
      && (    //ma2 k 穿过
         pre1Ma1>pre1Ma2 == Close[1]<pre1Ma2
         && (Close[1]>pre1Ma2 == Close[2]>pre2Ma2)
         && (Close[2]>pre2Ma2 != Close[3]>pre3Ma2)
         && (Close[3]>pre3Ma2 == Close[4]>pre4Ma2)
      )
      && pre1Ma1>pre1Ma2 == pre1Ma1>pre2Ma1
   ){
      if(pre1Ma1>pre2Ma1){
         type = OOPEN_BUY;
      }else{
         type = OOPEN_SELL;
      }
   }
   return type;
}

//fail
double maMaxDiff = 3;
double num_array[3];
int openFunShoots(){ //风平浪静的启动
   int type = 0;

   double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,1);
   double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
   double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,1);
   
   double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,2);
   double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
   double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,2);

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

   if(
      ((Close[1]>tempMax1 && Close[2]<tempMax2) || (Close[1]<tempMin1 && Close[2]>tempMin2))
      && tempMax1-tempMin1 < maMaxDiff
   ){
      if(Close[1]>pre1Ma1){
         type = OOPEN_BUY;
      }else{
         type = OOPEN_SELL;
      }
   }
   
   return type;
}

int closeStrategy(int i=0){
   int type = 0;

   type = closeFunShadow();

   return type;
}

int closeFunShadow(int i=0){
   int type = 0;

   return type;
}