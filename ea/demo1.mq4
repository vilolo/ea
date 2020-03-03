//+------------------------------------------------------------------+
//|                                                        demo1.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- input parameters
input int      ma1=5;
input int      ma2=10;
input int      ma4=28;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define MAGICMA  20131111

const int UP_4_SAME = 1;
const int UP_4_DIFF = 2;
const int DOWN_4_SAME = 3;
const int DOWN_4_DIFF = 4;
const int UP_2 = 5;
const int DOWN_2 = 6;

const int closeBuy = 1;
const int closeSell = 2;
const int kpool = 80;

void OnTick()
{
  //=== init ===
  int ordersTotal = OrdersTotal();

  if(Period() != 60) return;
  int pi;
  double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,1);
  double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,2);
  double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,1);
  double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,2);
  double pre1Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,1);
  double pre2Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,2);
  int openType = 0;
  int closeType = 0;
  //============
  if(ordersTotal == 0){ //判断开单
    //判断1叉4
    if(
      (pre1Ma1-pre1Ma4>0) != (pre2Ma1-pre2Ma4>0)
    ){
      if((pre1Ma1-pre1Ma4>0)){   //上叉
          //1方向与叉向是否一致
          if(pre1Ma1>pre2Ma1){ //朝向一致
            openType = UP_4_SAME;
          }else{
            openType = UP_4_DIFF;
          }
      }else{   //下叉
          //1方向与叉向是否一致
          if(pre1Ma1<pre2Ma1){ //朝向一致
            openType = DOWN_4_SAME;
          }else{
            openType = DOWN_4_DIFF;
          }
      }
    }else{
      //判断1叉2并且与4背离并且1与4大于5
      if(
          (pre1Ma1-pre1Ma2>0) != (pre2Ma1-pre2Ma2>0) &&
          (pre1Ma1-pre2Ma1>0) != (pre1Ma4-pre2Ma4>0) &&
          fabs(pre1Ma1 - pre1Ma4) > 5
      ){
          if(pre1Ma1-pre1Ma2>0){
            openType = UP_2;
          }else{
            openType = DOWN_2;
          }
      }
    }

    if(openType == 0) return;

    double point1Price=pre1Ma1;
    double point2Price=0;
    double point3Price=0;
    int point2Position=0;
    int point3Position=0;
    double part1TotalDiff=fabs(pre2Ma1-pre2Ma4);
    double part2TotalDiff=1;
    int part1DiffNum=0;
    int part2DiffNum=0;

    double pma1K1, pma4K1, pma1K2, pma4K2, tempDiff;
    int position;
    for(pi=0; pi<kpool; pi++){   //往前最多找kpool次
      if(point3Price>0) break;
      position = pi+3;  //0：当前未走，1：叉后，2：叉前
      pma1K1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+position);
      pma4K1 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+position);

      pma1K2 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+position+1);
      pma4K2 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+position+1);

      if(
         (pma1K1-pma4K1>0) != (pma1K2-pma4K2>0)
      ){
         if(point2Price==0){
            point2Price = pma1K1;
            point2Position = position;
         }else{
            point3Price = pma1K1;
            point3Position = position;
         }
      }

      tempDiff = fabs(pma1K1-pma4K1);
      if(point2Price==0){
         part1TotalDiff += tempDiff;
         part1DiffNum++;
      }else{
         part2TotalDiff += tempDiff;
         part2DiffNum++;
      }
    }

    if(type < UP_2){  //1叉4情况

    }else{   //1叉2情况
      if(part2DiffNum == 0 || part1TotalDiff/part1DiffNum < part2TotalDiff/part2DiffNum*1.5){  //前一浪平均值大于前前浪平均值2倍
          return;
      }
    }
  }else{  //判断平仓和是否反方向开单
    //判断当前方向
    if(
      pre1Ma1 > pre1Ma4
      // || 其他条件
    ){  //多，平空
      closeType = closeSell;
    }else{  //空, 平多
      closeType = closeBuy;
    }
  }

  int ticket;
  if(
    openType > 0 && 
    openType != UP_4_DIFF &&  //不同向考虑不开单
    openType != DOWN_4_DIFF
  ){
    if(
      openType==UP_4_SAME ||
      //openType==UP_4_DIFF ||  
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

  if(closeType > 0){
    for(int cnt=0;cnt<ordersTotal;cnt++){
      if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(closeType == closeBuy){  //平多
        if(OrderType()==OP_BUY){
          if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Violet))
            Print("OrderClose buy error ",GetLastError());
        }
      }else{
        if(OrderType()==OP_SELL){
          if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Violet))
            Print("OrderClose sell error ",GetLastError());
        }
      }
    }
  }
}


//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
   double ret=0.0;
   return(ret);
  }
//+------------------------------------------------------------------+
