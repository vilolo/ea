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
#property indicator_buffers 20
#property indicator_plots   4
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
input int      ma4=28;


//--- indicator buffers
double         ma1Buffer[];
double         ma2Buffer[];
double         ma3Buffer[];
double         ma4Buffer[];


//--- 统一定义的常量
string tips[20];
const long chart_ID = 0;
int kpool=80;

string objNameReferenceUp = "referenceLineUp";  //参考线
string objNameReferenceDown = "referenceLineDown";

bool isFirst = true; //第一次遍历所有历史，往后只遍历100即可
int tempi = 0;
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

   tempi = (isFirst ? rates_total-kpool : 100);
   for(int i=0;i<tempi;i++){
      if(isFirst) isFirst=false;
      if(i+110>rates_total) break;
      
      drawMa(i);
      strategy3(i,rates_total,time, open);
      //strategy1(i,rates_total,time, open);
      //strategy2(i,rates_total,time, open);
   }
   
   return rates_total;
}

const int UP_4_SAME = 1;
const int UP_4_DIFF = 2;
const int DOWN_4_SAME = 3;
const int DOWN_4_DIFF = 4;
const int UP_2 = 5;
const int DOWN_2 = 6;

//判断是否（1叉2并且与4背离并且1与4大于5）或1叉4
bool printFlag = true;
void strategy3(int i, int rates_total, const long &time[], const double &open[]){
   if(Period() != 60) return;
   
   int pi = 1;
   double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   double pre1Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre2Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi+1);

   int type = 0;
   //判断1叉4
   if(
      (pre1Ma1-pre1Ma4>0) != (pre2Ma1-pre2Ma4>0)
   ){
      if((pre1Ma1-pre1Ma4>0)){   //上叉
         //1方向与叉向是否一致
         if(pre1Ma1>pre2Ma1){ //朝向一致
            type = UP_4_SAME;
         }else{
            type = UP_4_DIFF;
         }
      }else{   //下叉
         //1方向与叉向是否一致
         if(pre1Ma1<pre2Ma1){ //朝向一致
            type = DOWN_4_SAME;
         }else{
            type = DOWN_4_DIFF;
         }
      }
   }else{
      //判断1叉2并且与4背离并且1与4大于5
      if(
         (pre1Ma1-pre1Ma2>0) != (pre2Ma1-pre2Ma2>0) &&
         (pre1Ma1-pre2Ma1>0) != (pre1Ma4-pre2Ma4>0) &&
         fabs(pre1Ma1 - pre1Ma4) > 8
      ){
         if(pre1Ma1-pre1Ma2>0){
            type = UP_2;
         }else{
            type = DOWN_2;
         }
      }
   }

   //过滤
   if(type == 0) return;

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

   // if(printFlag && i>50){
   //    printFlag = false;
   //    printf("**********************");
   //    printf(i);
   //    printf(point1Price);
   //    printf(point2Price);
   //    printf(point3Price);
   //    printf(point2Position);
   //    printf(point3Position);
   //    printf(part1TotalDiff);
   //    printf(part1DiffNum);
   //    printf(part1TotalDiff/part1DiffNum);
   //    printf(part2TotalDiff);
   //    printf(part2DiffNum);
   //    printf(part2TotalDiff/part2DiffNum);

   //    logVline(time[i], "=i=");
   //    logVline(time[i+point2Position], "point2Position");
   //    logVline(time[i+point3Position], "point3Position");
   // }
   
   //分析数据
   if(type < UP_2){  //1叉4情况

   }else{   //1叉2情况
      if(part2DiffNum == 0 || part1TotalDiff/part1DiffNum < part2TotalDiff/part2DiffNum*1.5){  //前一浪平均值大于前前浪平均值1.5倍
         return;
      }
   }

   //过滤后确定为有用点
   drawVline(type, time[i], open[i]);
}

void logVline(datetime t, string objName){
   ObjectCreate(chart_ID, objName, OBJ_VLINE, 0, t, 0);
   ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
   ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clrRed); 
}

void drawVline(int type, datetime t, double openPrice){
   //if(type < 5) return;
   string objName = "undefined_";
   int clr = clrRed;
   switch(type){
      case 1:
         objName = "UP_4_SAME_";
         clr = clrRed;
         openPrice += 5;
         break;
      case 2:
         objName = "UP_4_DIFF_";
         clr = clrDeepPink;
         openPrice += 5;
         break;
      case 3:
         objName = "DOWN_4_SAME_";
         openPrice -= 5;
         clr = clrLime;
         break;
      case 4:
         objName = "DOWN_4_DIFF_";
         clr = clrYellowGreen;
         openPrice -= 5;
         break;
      case 5:
         objName = "UP_2_";
         clr = clrPurple;
         openPrice += 5;
         break;
      case 6:
         objName = "DOWN_2_";
         clr = clrSandyBrown;
         openPrice -= 5;
         break;
   }

   StringAdd(objName, t);
   ObjectCreate(chart_ID, objName, OBJ_VLINE, 0, t, 0);
   ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
   ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 
   
   // StringAdd(objName, "text");
   // ObjectCreate(chart_ID, objName, OBJ_TEXT, 0, t, openPrice+5);
   // ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
   // ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 
   // ObjectSetString(chart_ID,objName,OBJPROP_TEXT,objName);
}


//1叉4策略
//循环数据，然后往前找1叉2的点，如果离得远或值相差很大，则过滤掉

string objVline_14 = "vline14_";
bool is1Up4;
void strategy1(int i, int rates_total, const long &time[], const double &open[]){
   if(Period() != 60) return;
   int pi = 1;
   double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre1Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   double pre2Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   
   //判断前k是否交叉
   if(
      //其他过滤条件
      (pre1Ma1-pre1Ma4>0) != (pre2Ma1-pre2Ma4>0)
   ){
      is1Up4 = pre1Ma1>pre1Ma4;  //？？也可以pre1Ma1>pre2Ma1
      if(is1Up4){
         string buyTips14 = "buy14_";
         string vlineBuy14 = "vlineBuy14_";
         StringAdd(vlineBuy14, time[i]);
         ObjectCreate(chart_ID, vlineBuy14, OBJ_VLINE, 0, time[i], 0);
         ObjectSetInteger(chart_ID,vlineBuy14,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,vlineBuy14,OBJPROP_COLOR,clrRed); 
         
         //StringAdd(buyTips14, time[i]);
         //ObjectCreate(chart_ID, buyTips14, OBJ_TEXT, 0, time[i], open[i]+5);
         //ObjectSetInteger(chart_ID,buyTips14,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         //ObjectSetInteger(chart_ID,buyTips14,OBJPROP_COLOR,clrRed); 
         //ObjectSetString(chart_ID,buyTips14,OBJPROP_TEXT,buyTips14);
      }else{
         string saleTips14 = "sale14_";
         string vlineSale14 = "vlineSale14_";
         StringAdd(vlineSale14, time[i]);
         ObjectCreate(chart_ID, vlineSale14, OBJ_VLINE, 0, time[i], 0);
         ObjectSetInteger(chart_ID,vlineSale14,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,vlineSale14,OBJPROP_COLOR,clrYellow); 
         
         //StringAdd(saleTips14, time[i]);
         //ObjectCreate(chart_ID, saleTips14, OBJ_TEXT, 0, time[i], open[i]-5);
         //ObjectSetInteger(chart_ID,saleTips14,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         //ObjectSetInteger(chart_ID,saleTips14,OBJPROP_COLOR,clrYellow); 
         //ObjectSetString(chart_ID,saleTips14,OBJPROP_TEXT,saleTips14);
      }
      
      //继续向前找交叉点
      //double node[10];  //交点
      //double peak[10];  //交点间的最大最小值
      //int peakPosition[10];   //峰值出现的位置
      //int nodePeriod[10];   //交点间的周期
      //int countNodePeriod = 1;   //计数多少周期, 0=交叉后，1=交叉前，从交叉前开始算
      //int indexNode = 0;   //索引
      //double maxDistanceMa1to4[10]; //ma1 与ma4 最大的距离
      //int maxDistanceMa1to4Position[10]; //ma1 与ma4 最大的距离
      
   }
}


//1叉2策略，判断是否是1叉2，然后往前找开口最大的地方是否超过5
//1叉2点A，往前找1叉4点B，然后再往前找1叉2点C，看前面B到C差多远和，A到

//！！或者，当前1叉2点 与前面的1叉4，再前面的第一个1叉2，再前面的一叉4对比，然后还可以对比第一个1叉2的点是否比上上个1叉4的还低，2月3日16点的例子就很明显
//标记出全面这些线，然后先肉眼看
//开窗口形式如macd的话，还可以标记当前1叉2，与前前1叉4的差值
bool is1Up2;
void strategy2(int i, int rates_total, const long &time[], const double &open[]){
   int pi = 1;
   double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi);
   double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
   
   double pre1Ma4 = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i+pi);
   
   if(
      //其他过滤条件
      (pre1Ma1-pre1Ma2>0) != (pre2Ma1-pre2Ma2>0) && 
      fabs(pre1Ma1-pre1Ma4) > 5
   ){
   
      is1Up2 = pre1Ma1>pre1Ma2;
      if(is1Up2){
         string vlineBuy12 = "vlineBuy12_";
         StringAdd(vlineBuy12, time[i]);
         ObjectCreate(chart_ID, vlineBuy12, OBJ_VLINE, 0, time[i], 0);
         ObjectSetInteger(chart_ID,vlineBuy12,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,vlineBuy12,OBJPROP_COLOR,clrAqua); 
         
         string buyTips12 = "buy12_";
         StringAdd(buyTips12, time[i]);
         ObjectCreate(chart_ID, buyTips12, OBJ_TEXT, 0, time[i], open[i]+5);
         ObjectSetInteger(chart_ID,buyTips12,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,buyTips12,OBJPROP_COLOR,clrRed); 
         ObjectSetString(chart_ID,buyTips12,OBJPROP_TEXT,buyTips12);
      }else{
         string vlineSale12 = "vlineSale12_";
         StringAdd(vlineSale12, time[i]);
         ObjectCreate(chart_ID, vlineSale12, OBJ_VLINE, 0, time[i], 0);
         ObjectSetInteger(chart_ID,vlineSale12,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,vlineSale12,OBJPROP_COLOR,clrBeige); 
         
         string saleTips12 = "sale12_";
         StringAdd(saleTips12, time[i]);
         ObjectCreate(chart_ID, saleTips12, OBJ_TEXT, 0, time[i], open[i]-5);
         ObjectSetInteger(chart_ID,saleTips12,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
         ObjectSetInteger(chart_ID,saleTips12,OBJPROP_COLOR,clrYellow); 
         ObjectSetString(chart_ID,saleTips12,OBJPROP_TEXT,saleTips12);
      }
   }
}

void drawMa(int i){
   ma1Buffer[i] = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i);
   ma2Buffer[i] = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i);
   //ma3Buffer[i] = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i);
   ma4Buffer[i] = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i);
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
   // tips[1] = "均线的共振，为什么30均线有用？量变变质变？";
   // tips[2] = "列举问题：";
   // tips[3] = "a.如何区分单边和震荡（1小时线）";
   // tips[4] = "b.如何预计下一波的大小或持续的时间长短";
   // tips[5] = "c.一个个买点的找";
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