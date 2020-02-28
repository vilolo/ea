//+------------------------------------------------------------------+
//|                                                        demo1.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define MAGICMA  20131111
bool tickOnce = true;
void OnTick()
  {
//---
   if(Bars<100 || IsTradeAllowed()==false){
      //printf("not allow trade");
   }
   
   if(tickOnce){
      int res = OrderSend(Symbol(),OP_BUY,0.1,Ask,3,0,0,"comment",MAGICMA,0,Blue);
   
      //printf("==============");
      //printf(res);
      
      int err = GetLastError();
      printf(err);
      
      tickOnce = false;
   }
   
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
