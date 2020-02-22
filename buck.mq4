//+------------------------------------------------------------------+
//|                                                        buck3.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 30
#property indicator_plots   10
//--- plot ma1
#property indicator_label1  "ma1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1
//--- plot ma2
#property indicator_label2  "ma2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1
//--- plot ma3
#property indicator_label3  "ma3"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrAqua
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
//--- plot ma4
#property indicator_label4  "ma4"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrBlueViolet
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#property indicator_type5  DRAW_ARROW
#property indicator_color5 clrRed

//--- input parameters
input int      ma1=5;
input int      ma2=10;
input int      ma3=20;
input int      ma4=30;
//--- indicator buffers
double         ma1Buffer[];
double         ma2Buffer[];
double         ma3Buffer[];
double         ma4Buffer[];

double   buyPointBuffer[];
double   maArray[4];

string tips[20];

long chart_ID = 0;

const int ISTOP = 1;

string referenceUp = "referenceUp";
string referenceDown = "referenceDown";

int buyIndex = 0;
int saleIndex = 0;
int vlineIndex = 0;

//交点
double cross[10];
//交点间的峰值
double peak[10];
//峰值在第几个位置
int peakPosition[10];
//两交点间的周期数
int crossPerid[10];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,ma1Buffer);
   SetIndexBuffer(1,ma2Buffer);
   SetIndexBuffer(2,ma3Buffer);
   SetIndexBuffer(3,ma4Buffer);
   
   SetIndexBuffer(4,buyPointBuffer);   SetIndexArrow(4, 233);
   //SetIndexBuffer(5,maArray);
   
   long handle=ChartID(); 
   if(handle>0) // If it succeeded, additionally customize 
   { 
      ChartSetInteger(handle, CHART_SCALE, 2);
      ChartSetInteger(handle,CHART_AUTOSCROLL,true); 
      ChartSetInteger(handle,CHART_MODE,CHART_CANDLES); 
      ChartSetInteger(handle,CHART_SHOW_VOLUMES,true); 
      ChartSetInteger(handle,CHART_BRING_TO_TOP,0,true);
      ChartSetInteger(handle,CHART_FOREGROUND,0,true);
   }
   
   if(ObjectFind(chart_ID, referenceUp) != 0){
      if(!ObjectCreate(chart_ID, referenceUp, OBJ_HLINE,0, 0, 1600)){
         Print(__FUNCTION__, 
            ": failed to create OBJ_HLINE! Error code = ",GetLastError());
      }else{
         ObjectSetInteger(chart_ID,referenceUp,OBJPROP_STYLE,STYLE_DASHDOTDOT);
         ObjectSetInteger(chart_ID, referenceUp,OBJPROP_COLOR,clrOrangeRed);
      }
   }
   
   if(ObjectFind(chart_ID, referenceDown) != 0){
      if(!ObjectCreate(chart_ID, referenceDown, OBJ_HLINE,0, 0, 1600)){
         Print(__FUNCTION__, 
            ": failed to create OBJ_HLINE! Error code = ",GetLastError());
      }else{
         ObjectSetInteger(chart_ID,referenceDown,OBJPROP_STYLE,STYLE_DASHDOTDOT);
         ObjectSetInteger(chart_ID, referenceDown,OBJPROP_COLOR,clrDarkViolet);
      }
   }
   
   tips[0] = "如何理解单边行情和震荡行情呢？均线是怎么体现的";
   tips[1] = "均线的共振，为什么30均线有用？量变变质变？";
   tips[2] = "列举问题：";
   tips[3] = "a.如何区分单边和震荡（1小时线）";
   tips[4] = "b.如何预计下一波的大小或持续的时间长短";
   tips[5] = "c.一个个买点的找";
   writeTips();
   
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
//---
   ObjectSet(referenceUp,1,close[0]+5);
   ObjectSet(referenceDown,1,close[0]-5);
   
   for(int i=0;i<rates_total;i++){
      drawMa(i);
      
      //buyPoint(i, rates_total, low);
      //buyPoint2(i,rates_total,close,open,low,high);
      
      if(Period() == 60){
         //buyPoint3(i, time);
         //buyPoint4(i, rates_total, time);
         //buyPoint5(i, rates_total, time, open, low, high);
         buyPoint6(i, rates_total, time, open);
      }
      //objText(i,ISTOP,i,time,high,low);
      
   }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
  
void drawMa(int i){
   ma1Buffer[i] = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i);
   ma2Buffer[i] = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i);
   ma3Buffer[i] = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i);
   ma4Buffer[i] = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i);
}

//判断前一根是否有叉点
//继续往前追溯kpool看有多少个角度
//记录叉点的值，期间持续的周期，以及期间短均线的峰值
void buyPoint6(int i, int rates_total, const long &time[], const double &open[]){
   int kpool = 80;
   if(i+kpool >= rates_total) return;

   ArrayFree(cross);
   ArrayFree(peak);
   ArrayFree(peakPosition);
   ArrayFree(crossPerid);
   
   ArrayResize(cross, 10);
   ArrayResize(peak, 10);
   ArrayResize(peakPosition, 10);
   ArrayResize(crossPerid, 10);
   
   int pi = 1;
   double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre1Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi);
   
   double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   double pre2Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   
   //判断是否是1叉2
   if(
      i < 500 && 
      (pre1Ma1-pre1Ma4>0) != (pre2Ma1-pre2Ma4>0)
   ){
      
      string name = "vline12_";
      StringAdd(name, i);
      ObjectCreate(chart_ID, name, OBJ_VLINE, 0, time[i], 0);
      ObjectSetInteger(chart_ID,name,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
      
      if(pre1Ma1>pre1Ma4){//上涨
         string pname = "buy12_";
         StringAdd(pname, buyIndex++);
         ObjectCreate(chart_ID, pname, OBJ_TEXT, 0, time[i], open[i]+5);
         ObjectSetInteger(chart_ID,pname,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,pname,OBJPROP_COLOR,clrRed); 
         ObjectSetString(chart_ID,pname,OBJPROP_TEXT,pname);
         
         ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clrRed); 
   
      }else{
         string pname = "sale12_";
         StringAdd(pname, saleIndex++);
         ObjectCreate(chart_ID, pname, OBJ_TEXT, 0, time[i], open[i]-5);
         ObjectSetInteger(chart_ID,pname,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,pname,OBJPROP_COLOR,clrLime); 
         ObjectSetString(chart_ID,pname,OBJPROP_TEXT,pname);
         
         ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clrYellow); 
      }
      
      cross[0] = pre1Ma1;
      pi++;
      int countPeriod = 0;
      int indexCross = 1;
      
      //如果1上叉4，则往前找低值，根据上一个交点判断峰值是找最大值还是最小值
      bool isFindLow = (pre1Ma1-pre1Ma4>0);
      peak[indexCross] = pre1Ma1;
      for(pi;pi<kpool;pi++)
      {
         if(ArrayMinimum(cross)==0) break; //交点数答到数组最大值
         countPeriod++;
         pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
         pre1Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi);
         
         pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
         pre2Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
         
         peakPosition[indexCross] = countPeriod;
         if(isFindLow){
            if(peak[indexCross]>pre1Ma1){
               peak[indexCross] = pre1Ma1;
            }
         }else{
            if(peak[indexCross]<pre1Ma1){
               peak[indexCross] = pre1Ma1;
            }
         }
         
         if(
            (pre1Ma1-pre1Ma4>0) != (pre2Ma1-pre2Ma4>0)
         ){
            isFindLow = !isFindLow;
            indexCross++;
            cross[indexCross] = pre1Ma1;
            crossPerid[indexCross] = countPeriod;
            countPeriod = 0;
         }
      }
      

      printf("-------------");
      printf(cross[0]);
      printf(peak[1]);
      printf(peakPosition[1]);
      printf(crossPerid[1]);
      printf(cross[1]);
   }
}

//找到5日均线穿过30日均线的点
void buyPoint5(int i, int rates_total, const long &time[], const double &open[], const double &low[], const double &high[]){

   double curMa1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+1);
   double nextMa1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+2);
   
   double curMa4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+1);
   double nextMa4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+2);
   
   if(
      (curMa1-curMa4>0) != (nextMa1-nextMa4>0)
   ){
      string name = "vline14_";
      StringAdd(name, vlineIndex++);
      ObjectCreate(chart_ID, name, OBJ_VLINE, 0, time[i], 0);
      ObjectSetInteger(chart_ID,name,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
      
      if(curMa1>nextMa1){//上涨
         string pname = "buy14_";
         StringAdd(pname, buyIndex++);
         ObjectCreate(chart_ID, pname, OBJ_TEXT, 0, time[i], open[i]+5);
         ObjectSetInteger(chart_ID,pname,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,pname,OBJPROP_COLOR,clrRed); 
         ObjectSetString(chart_ID,pname,OBJPROP_TEXT,pname);
         
         ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clrRed); 

      }else{
         string pname = "sale14_";
         StringAdd(pname, saleIndex++);
         ObjectCreate(chart_ID, pname, OBJ_TEXT, 0, time[i], open[i]-5);
         ObjectSetInteger(chart_ID,pname,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,pname,OBJPROP_COLOR,clrLime); 
         ObjectSetString(chart_ID,pname,OBJPROP_TEXT,pname);
         
         ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clrYellow); 
      }
   }
}

//上一均线最大最小差值小于3，并且比上上均线差值大
//上上均线差值比上上的前5期均线差值的平均值要小
//根据差值判断开口方向
void buyPoint4(int i, int rates_total, const long &time[]){
   int kpool = 10;
   if(i+kpool >= rates_total) return;
   
   int index = 1;
   
   maArray[0] = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+index);
   maArray[1] = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+index);
   maArray[2] = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+index);
   maArray[3] = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+index);

   int max_1 = ArrayMaximum(maArray);
   int min_1 = ArrayMinimum(maArray);
   
   if(fabs(maArray[max_1] - maArray[min_1]) > 3) return;
   
   index = 2;
   maArray[0] = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+index);
   maArray[1] = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+index);
   maArray[2] = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+index);
   maArray[3] = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+index);
   
   int max_2 = ArrayMaximum(maArray);
   int min_2 = ArrayMinimum(maArray);
   double margin_2 = fabs(maArray[max_2]-maArray[min_2]);
   
   if(fabs(maArray[max_1]-maArray[min_1])<margin_2) return;
   
   double margin_total = 0;
   for(int pi=1;pi<kpool-3;pi++)
   {
      maArray[0] = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+index+pi);
      maArray[1] = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+index+pi);
      maArray[2] = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+index+pi);
      maArray[3] = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+index+pi);

      margin_total += fabs(maArray[ArrayMaximum(maArray)]-maArray[ArrayMinimum(maArray)]);
   }
   
   if(margin_total/(kpool-4)<margin_2) return;
   
   string name = "vline_";
   StringAdd(name, i);
   ObjectCreate(chart_ID, name, OBJ_VLINE, 0, time[i], 0);
   ObjectSetInteger(chart_ID,name,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
}

void writeTips(){
   string name = "tips_";
   if(ArraySize(tips) > 0){
      for(int i=0;i<ArraySize(tips);i++)
      {
         if(tips[i] != NULL){
            string text = i;
            StringAdd(name, i);
            if(!ObjectCreate(chart_ID, name, OBJ_LABEL, 0, 0, 0)){
               Print(__FUNCTION__, 
                     ": failed to create text label! Error code = ",GetLastError()); 
            }else{
               StringAdd(text, ". ");
               StringAdd(text, tips[i]);
               ObjectSetString(chart_ID,name,OBJPROP_TEXT,text); 
               ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,50); 
               ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,(i+1)*20+10); 
               ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clrRed);
            }
         }
      }
   }
}

//买多点策略1：均线3,4交叉点，与1,2均线的距离小于5
void buyPoint(int i, int rates_total, const double &low[]){
   if(i+1> rates_total) return;
   
   double tempMa1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i);
   double tempMa2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i);
   double tempMa3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i);
   double tempMa4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i);
   
   if(
      //触发点：3均线大于4均线
      tempMa3>tempMa4 && 
      //
      fabs(tempMa1-tempMa3)<2 && fabs(tempMa2-tempMa3)<2 &&
      iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+1)>iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+2) &&
      iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1)>iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2) &&
      iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+1)>iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+2) &&
      iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+1)<iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+1) &&
      ((tempMa1>tempMa2?tempMa1:tempMa2)-tempMa4)<5
   ){
      buyPointBuffer[i] = low[i]-5;
   }
}

//前一根k线是阳线，收盘大于4均线，上引线不能超过整体的一半
//当前均线全部向上
//四根均线最大最小值不超过5
//此前8根收盘价不能全都大于4均线，至少3根最高价大于4均线

//??还是要加入布林带的上下轨，否则不知如何确定上下轨好
void buyPoint2(int i, int rates_total, const double &close[], const double &open[], const double &low[], const double &high[]){
   if(i+30> rates_total) return;
   
   double tempMa4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i);
   if(close[i+1]<open[i+1] || close[i+1]<tempMa4 || 
      (high[i+1]-close[i+1]>close[i+1]-low[i+1])
   ) return;
   
   double tempMa1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i);
   double tempMa2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i);
   double tempMa3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i);
   
   maArray[0] = tempMa1;
   maArray[1] = tempMa2;
   maArray[2] = tempMa3;
   maArray[3] = tempMa4;
   
   if(
      tempMa1>iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+1) &&
      tempMa2>iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1) &&
      tempMa3>iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+1) &&
      tempMa4>iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+1) &&
      (ArrayMaximum(maArray)-ArrayMinimum(maArray))<5
   ){
      bool condition1 = false;   //存在小于4均线的
      int condition2 = 0;
      for(int pi=i+1;pi<i+8;pi++)
      {
         if(!condition1 && close[pi]<iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,pi)){
            condition1 = true;
         }
         
         if(condition2<3 && close[pi]>iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,pi)){
            condition2++;
         }
      }
      
      if(condition1 && condition2==3){
         buyPointBuffer[i] = low[i]-5;
      }
   }
   
}

//触发点：前一根3均线大于4均线
//前30根K线，3均线都小于4均线，1均线大于3均线的不超过10根

//均线大口变小口？？

void buyPoint3(int i, const long &time[]){
   //先画出所以3,4均线交叉位置
   double curMa3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i);
   double nextMa3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+1);
   
   double curMa4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i);
   double nextMa4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+1);
   
   if(
      (curMa3-curMa4>0) != (nextMa3-nextMa4>0)
   ){
      string name = "vline_";
      StringAdd(name, i);
      ObjectCreate(chart_ID, name, OBJ_VLINE, 0, time[i], 0);
      ObjectSetInteger(chart_ID,name,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
   }
}

void objText(int i, int type, string text, const long &time[], const double &high[], const double &low[]){
   double price = type==ISTOP ? high[i]+5 : low[i]-5;
   string name = "text_";
   StringAdd(name, string(i));
   if(!ObjectCreate(chart_ID,name,OBJ_TEXT,0,time[i],price)) 
   { 
      Print(__FUNCTION__, 
            ": failed to create text label! Error code = ",GetLastError()); 
   }
   
   //--- set the text 
   ObjectSetString(chart_ID,name,OBJPROP_TEXT,text); 
//--- set text font 
   ObjectSetString(chart_ID,name,OBJPROP_FONT,"Arial"); 
//--- set font size 
   ObjectSetInteger(chart_ID,name,OBJPROP_FONTSIZE,10); 
//--- set the slope angle of the text 
   ObjectSetDouble(chart_ID,name,OBJPROP_ANGLE,90); 
//--- set anchor type 
   ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER); 
//--- set color 
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clrRed); 
//--- display in the foreground (false) or background (true) 
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,false); 
//--- enable (true) or disable (false) the mode of moving the object by mouse 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,false); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,false); 
//--- hide (true) or display (false) graphical object name in the object list 
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,true); 
//--- set the priority for receiving the event of a mouse click in the chart 
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,0); 
   ObjectSetInteger(chart_ID,name,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
}

  
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
