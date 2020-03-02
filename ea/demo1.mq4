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
input int      ma3=28;

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

void OnTick()
{
  //=== init ===
  int ordersTotal = OrdersTotal();

  if(Period() != 60) return;
  int pi = 1;
  double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
  double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
  double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi);
  double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
  double pre1Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi);
  double pre2Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
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
  }else{  //判断平仓和是否方向开单
    
  }

  if(openType > 0){
    if(
      openType==UP_4_SAME ||
      openType==UP_4_DIFF ||
      openType==UP_2
    ){
      int res = OrderSend(Symbol(),OP_BUY,0.1,Ask,3,0,0,"comment",MAGICMA,0,Blue);
    }else{

    }
  }

  if(closeType > 0){

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
