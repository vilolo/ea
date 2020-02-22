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

int vBuyIndex=0;
int vSaleIndex=0;
long vlineBuy[500];  //不够需要加或动态加
long vlineSale[500];
double vBuyOpen[500];
double vSaleOpen[500];

//--- 统一定义的常量
string tips[20];
const long chart_ID = 0;

//分析数据1
double node[10];  //交点
double peak[10];  //交点间短周期的最大最小值
int peakPosition[10];   //峰值出现的位置
int nodePeriod[10];   //交点间的周期
int countNodePeriod = 0;   //计数多少周期
int indexNode = 0;   //索引

string objNameReferenceUp = "referenceLineUp";  //参考线
string objNameReferenceDown = "referenceLineDown";

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
   ObjectSet(objNameReferenceUp,1,close[0]+5);
   ObjectSet(objNameReferenceDown,1,close[0]-5);
   
   for(int i=0;i<rates_total;i++){
      drawMa(i);
      getNodeData(i,rates_total,time, open);
      strategy1(i);
      
      ArrayFree(node);
      ArrayFree(peak);
      ArrayFree(peakPosition);
      ArrayFree(nodePeriod);
      
      ArrayResize(node, 10);
      ArrayResize(peak, 10);
      ArrayResize(peakPosition, 10);
      ArrayResize(nodePeriod, 10);
   }
   
   drawVline();
   
   return rates_total;
}

int kpool=80;
int pi = 0;
string objVline_14 = "vline14_";
bool is1Up4;
void getNodeData(int i, int rates_total, const long &time[], const double &open[]){
   if(i+kpool >= rates_total-100) return;
   indexNode = 0;
   
   pi = 1;
   double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre1Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   double pre2Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   
   //判断前k是否交叉
   if(
      //其他过滤条件
      (pre1Ma1-pre1Ma4>0) != (pre2Ma1-pre2Ma4>0)
   ){
      is1Up4 = pre1Ma1>pre1Ma4;
      if(is1Up4){
         vlineBuy[vBuyIndex] = time[i];
         vBuyOpen[vBuyIndex] = open[i];
         vBuyIndex++;
      }else{
         vlineSale[vSaleIndex] = time[i];
         vSaleOpen[vSaleIndex] = open[i];
         vSaleIndex++;
      }
      
      node[indexNode] = pre1Ma1;
      nodePeriod[indexNode] = countNodePeriod;
      peak[indexNode] = pre1Ma1;
      peakPosition[indexNode] = countNodePeriod;
      
      //继续向前找交叉点
      pi++;
      for(pi; pi<kpool; pi++){
         if(node[ArrayMinimum(node)]!=0) break;
         
         double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
         double pre1Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi);
         double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
         double pre2Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
         if(
            (pre1Ma1-pre1Ma4>0) != (pre2Ma1-pre2Ma4>0)
         ){
            indexNode++;
            is1Up4 = !is1Up4;
            countNodePeriod = 0;
            node[indexNode] = pre1Ma1;
         }else{
            countNodePeriod++;
         }
         
         nodePeriod[indexNode] = countNodePeriod;
         
         if(is1Up4 && peak[indexNode]>pre1Ma1){
            peak[indexNode] = pre1Ma1;
            peakPosition[indexNode] = countNodePeriod;
         }
         
         if(!is1Up4 && peak[indexNode]<pre1Ma1){
            peak[indexNode] = pre1Ma1;
            peakPosition[indexNode] = countNodePeriod;
         }
      }
   }
}

//1叉4策略
//循环数据，然后往前找1叉2的点，如果离得远或值相差很大，则过滤掉
void strategy1(int i){
   //test
   if(i>100) return;

   printf("===============");
   printf(i);
   printf(node[0]);
   printf(peak[0]);
   printf(peakPosition[0]);
   printf(nodePeriod[0]);
   printf(node[1]);
}

//1叉2策略
void strategy2(){

}

void drawMa(int i){
   ma1Buffer[i] = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i);
   ma2Buffer[i] = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i);
   ma3Buffer[i] = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i);
   ma4Buffer[i] = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i);
}

void drawVline(){
   for(int i=0; i<ArraySize(vlineBuy); i++){
      if(vlineBuy[i] > 0){
         string buyTips14 = "buy14_";
         string vlineBuy14 = "vlineBuy14_";
         StringAdd(vlineBuy14, i);
         ObjectCreate(chart_ID, vlineBuy14, OBJ_VLINE, 0, vlineBuy[i], 0);
         ObjectSetInteger(chart_ID,vlineBuy14,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,vlineBuy14,OBJPROP_COLOR,clrRed); 
         
         StringAdd(buyTips14, i);
         ObjectCreate(chart_ID, buyTips14, OBJ_TEXT, 0, vlineBuy[i], vBuyOpen[i]+5);
         ObjectSetInteger(chart_ID,buyTips14,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,buyTips14,OBJPROP_COLOR,clrRed); 
         ObjectSetString(chart_ID,buyTips14,OBJPROP_TEXT,buyTips14);
      }else{
         break;
      }
   }
   
   for(int i=0; i<ArraySize(vlineSale); i++){
      if(vlineSale[i] > 0){
         string saleTips14 = "sale14_";
         string vlineSale14 = "vlineSale14_";
         StringAdd(vlineSale14, i);
         ObjectCreate(chart_ID, vlineSale14, OBJ_VLINE, 0, vlineSale[i], 0);
         ObjectSetInteger(chart_ID,vlineSale14,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,vlineSale14,OBJPROP_COLOR,clrYellow); 
         
         StringAdd(saleTips14, i);
         ObjectCreate(chart_ID, saleTips14, OBJ_TEXT, 0, vlineSale[i], vSaleOpen[i]-5);
         ObjectSetInteger(chart_ID,saleTips14,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,saleTips14,OBJPROP_COLOR,clrYellow); 
         ObjectSetString(chart_ID,saleTips14,OBJPROP_TEXT,saleTips14);
      }else{
         break;
      }
   }
}

int OnInit()
{
   SetIndexBuffer(0,ma1Buffer);
   SetIndexBuffer(1,ma2Buffer);
   SetIndexBuffer(2,ma3Buffer);
   SetIndexBuffer(3,ma4Buffer);
   
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
   
   if(ObjectFind(chart_ID, objNameReferenceUp) != 0){
      if(!ObjectCreate(chart_ID, objNameReferenceUp, OBJ_HLINE,0, 0, 1600)){
         Print(__FUNCTION__, 
            ": failed to create OBJ_HLINE! Error code = ",GetLastError());
      }else{
         ObjectSetInteger(chart_ID,objNameReferenceUp,OBJPROP_STYLE,STYLE_DASHDOTDOT);
         ObjectSetInteger(chart_ID, objNameReferenceUp,OBJPROP_COLOR,clrOrangeRed);
      }
   }
   
   if(ObjectFind(chart_ID, objNameReferenceDown) != 0){
      if(!ObjectCreate(chart_ID, objNameReferenceDown, OBJ_HLINE,0, 0, 1610)){
         Print(__FUNCTION__, 
            ": failed to create OBJ_HLINE! Error code = ",GetLastError());
      }else{
         ObjectSetInteger(chart_ID,objNameReferenceDown,OBJPROP_STYLE,STYLE_DASHDOTDOT);
         ObjectSetInteger(chart_ID, objNameReferenceDown,OBJPROP_COLOR,clrDarkViolet);
      }
   }
   
   tips[0] = "如何理解单边行情和震荡行情呢？均线是怎么体现的";
   tips[1] = "均线的共振，为什么30均线有用？量变变质变？";
   tips[2] = "列举问题：";
   tips[3] = "a.如何区分单边和震荡（1小时线）";
   tips[4] = "b.如何预计下一波的大小或持续的时间长短";
   tips[5] = "c.一个个买点的找";
   writeTips();
   
   return(INIT_SUCCEEDED);
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