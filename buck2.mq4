//+------------------------------------------------------------------+
//|                                                        buck2.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_separate_window
//#property indicator_minimum -100
//#property indicator_maximum 100
#property indicator_buffers 10
#property indicator_plots   10


//--- input parameters
input int      ma1=5;
input int      ma2=10;
input int      ma3=20;
input int      ma4=30;


#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_type2   DRAW_LINE
#property indicator_color3  clrBeige
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRed
#property indicator_style4  STYLE_DASHDOTDOT
#property indicator_width4  1

#property indicator_type5   DRAW_LINE
#property indicator_color5  clrLime
#property indicator_style5  STYLE_DASHDOTDOT
#property indicator_width5  1

#property indicator_label6  "Ma4+"
#property indicator_type6   DRAW_HISTOGRAM
#property indicator_color6  clrRed
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

#property indicator_label7  "Ma4-"
#property indicator_type7   DRAW_HISTOGRAM
#property indicator_color7  clrAqua
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

//--- indicator buffers
double         ma1To4[];
double         ma2To4[];
double         maZero[];
double         Top5[];
double         Low5[];
double         ma4High[];
double         ma4Low[];

//自定义
bool isFirst = true; //第一次遍历所有历史，往后只遍历100即可

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0,ma1To4);
   SetIndexBuffer(1,ma2To4);
   SetIndexBuffer(2,maZero);
   SetIndexBuffer(3,Top5);
   SetIndexBuffer(4,Low5);
   SetIndexBuffer(5,ma4High);
   SetIndexBuffer(6,ma4Low);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int totalK;
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
   //画一条0的中线
   ArrayInitialize(maZero, 0);
   ArrayInitialize(Top5, 5);
   ArrayInitialize(Low5, -5);
   
   totalK = (isFirst ? (rates_total>2000?2000:rates_total) : 30);
   double ima1, ima2, ima4, ima4Pre1, ival;
   for(int i=0;i<totalK;i++)
   {
      if(isFirst) isFirst=false;
      ima1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i);
      ima2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i);
      ima4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i);
      
      ima4Pre1 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+1);
      
      ma1To4[i] = ima1 - ima4;
      ma2To4[i] = ima2 - ima4;
      
      ival = (ima4-ima4Pre1)*5;
      if(ival>0){
         ma4High[i] = ival;
         ma4Low[i] = EMPTY_VALUE;
      }else{
         ma4Low[i] = ival;
         ma4High[i] = EMPTY_VALUE;
      }
   }
   
   return(rates_total);
}
