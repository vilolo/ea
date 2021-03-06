//+------------------------------------------------------------------+
//|                                                  ibuck_slope.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_separate_window

#property indicator_buffers 10
#property indicator_plots   10

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrAquamarine
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

#property indicator_label5  "Ma4+"
#property indicator_type5   DRAW_HISTOGRAM
#property indicator_color5  clrRed
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

#property indicator_label7  "Ma4-"
#property indicator_type7   DRAW_HISTOGRAM
#property indicator_color7  clrAqua
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

#property indicator_label8  "Ma4+"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrRed
#property indicator_style8  STYLE_SOLID
#property indicator_width8  1

#property indicator_label9  "Ma4-"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrLime
#property indicator_style9  STYLE_SOLID
#property indicator_width9  1

//--- input parameters
input int      ma1=5;
input int      ma2=10;
input int      ma3=28;

double ma1Slope[];
double ma2Slope[];
double ma3Slope[];

double ma13Up[];   //
double ma23Up[];

double ma13Down[];
double ma23Down[];

double topLine[];
double lowLine[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,ma1Slope);
   SetIndexBuffer(1,ma2Slope);
   SetIndexBuffer(2,ma3Slope);
   SetIndexBuffer(3,ma13Up);
   SetIndexBuffer(4,ma23Up);
   SetIndexBuffer(5,ma13Down);
   SetIndexBuffer(6,ma23Down);
   
   //SetIndexBuffer(7,topLine);
   //SetIndexBuffer(8,lowLine);
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int totalK;
bool isFirst = true;
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   ArrayInitialize(topLine, 5);
   ArrayInitialize(lowLine, -5);
   
   totalK = (isFirst ? (rates_total>2000?2000:rates_total) : 30);
   for(int i=0;i<totalK;i++)
   {
      if(isFirst) isFirst=false;
      
      double pre1ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+1);
      double pre1ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1);
      double pre1ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+1);
      
      int j = 3;
      double prejma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+1+j);
      double prejma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1+j);
      double prejma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+1+j);
      
      double slopeMa1 = (pre1ma1 - prejma1)/0.1;
      double slopeMa2 = (pre1ma2 - prejma2)/0.1;
      double slopeMa3 = (pre1ma3 - prejma3)/0.1;
      
      //ma1Slope[i] = slopeMa1;
      ma2Slope[i] = slopeMa2;
      ma3Slope[i] = slopeMa3;
      
      double pre2ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2);
      double pre2jma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2+j);
      double slope2Ma2 = (pre2ma2 - pre2jma2)/0.1;
      
      double pre2ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+2);
      double pre2jma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+2+j);
      double slope2Ma3 = (pre2ma3 - pre2jma3)/0.1;
      
      if(pre1ma2 > pre1ma3 ){
         ma23Up[i] = pre1ma2-pre1ma3;
      }else{
         ma23Down[i] = pre1ma2-pre1ma3;
      }
      
      
      if(
         (slopeMa2-slopeMa3>0) != (slope2Ma2-slope2Ma3>0)
         //&& (slopeMa3-slope2Ma3>0) == (slopeMa2-slope2Ma2>0)
      ){
         //string objName = "bb"+i;
         //ObjectCreate(0, objName, OBJ_VLINE, 0, time[i], 0);
         //ObjectSetInteger(0,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         //ObjectSetInteger(0,objName,OBJPROP_COLOR,clrRed); 
      }
   }
   
   return(rates_total);
}
