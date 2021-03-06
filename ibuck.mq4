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
#property indicator_color3  clrBlueViolet
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//============ strategy init ================
#define UP_13_UU 1  //up 1叉3，两个up
#define UP_13_UD 2  //up 1叉3，1up,3down
#define UP_13_DD 3  //up 1叉3，1down,3down

#define UP_12_UU 4
#define UP_12_UD 5
#define UP_12_DD 6
#define OPEN_BUY_AFTER_CLOSE 7

#define DOWN_13_UU 11
#define DOWN_13_DU 12
#define DOWN_13_DD 13

#define DOWN_12_UU 14
#define DOWN_12_DU 15
#define DOWN_12_DD 16
#define OPEN_SELL_AFTER_CLOSE 17

#define CLOSE_BUY 1
#define CLOSE_BUY_OPEN 2
#define CLOSE_BUY_STOP_PROFIT 3
#define CLOSE_BUY_STOP_LOSS 4
#define CLOSE_SELL 11
#define CLOSE_SELL_OPEN 12
#define CLOSE_SELL_STOP_PROFIT 13
#define CLOSE_SELL_STOP_LOSS 14
//============= strategy init end ==========

//--- input parameters
input int      ma1=5;
input int      ma2=10;
input int      ma3=28;
input double   slopeStd=1; //斜率

//--- indicator buffers
double         ma1Buffer[];
double         ma2Buffer[];
double         ma3Buffer[];

const long chart_ID = 0;
string tips[20];
string objNameReferenceUp = "referenceLineUp";  //参考线
string objNameReferenceDown = "referenceLineDown";

int OnInit()
{
    printf(TimeCurrent()-(TimeCurrent()%3600));
    SetIndexBuffer(0,ma1Buffer);
    SetIndexBuffer(1,ma2Buffer);
    SetIndexBuffer(2,ma3Buffer);

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

   tips[0] = "tips....";
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

int tempi;
bool isFirst = true; //第一次遍历所有历史，往后只遍历100即可
int kpool = 80;
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

        double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+1);
        double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+2);
        double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1);
        double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2);
        double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+1);
        double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+2);

        int openType = strategyOpen(i,
                pre1Ma1,pre2Ma1,pre1Ma2,pre2Ma2,pre1Ma3,pre2Ma3);

        if(openType > 0){
            drawOpen(openType, time[i], open[i]);
        }

        int closeType = strategyClose(i,
                pre1Ma1,pre2Ma1,pre1Ma2,pre2Ma2,pre1Ma3,pre2Ma3);

        if(closeType > 0){
            drawClose(closeType, time[i], open[i]);
        }
    }
    
    return rates_total;
}

void drawMa(int i){
   ma1Buffer[i] = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i);
   ma2Buffer[i] = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i);
   ma3Buffer[i] = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i);
}

void drawOpen(int type, datetime t, double openPrice){
    string objName = "undefined_";
    int clr = clrCadetBlue;

    switch(type){
        case UP_12_DD:
            objName = "UP_12_DD_";
            clr = clrRed;
            openPrice += 5;
            break;
        case UP_12_UD:
            objName = "UP_12_UD_";
            clr = clrRed;
            openPrice += 5;
            break;
        case UP_12_UU:
            objName = "UP_12_UU_";
            openPrice += 5;
            clr = clrRed;
            break;
        case UP_13_DD:
            objName = "UP_13_DD_";
            clr = clrRed;
            openPrice += 5;
            break;
        case UP_13_UD:
            objName = "UP_13_UD_";
            clr = clrRed;
            openPrice += 5;
            break;
        case UP_13_UU:
            objName = "UP_13_UU_";
            openPrice += 5;
            clr = clrRed;
            break;

        case DOWN_12_DD:
            objName = "UP_12_DD_";
            clr = clrLime;
            openPrice -= 5;
            break;
        case DOWN_12_DU:
            objName = "DOWN_12_DU_";
            clr = clrLime;
            openPrice -= 5;
            break;
        case DOWN_12_UU:
            objName = "DOWN_12_UU_";
            openPrice -= 5;
            clr = clrLime;
            break;
        case DOWN_13_DD:
            objName = "UP_13_DD_";
            clr = clrLime;
            openPrice -= 5;
            break;
        case DOWN_13_DU:
            objName = "DOWN_13_DU_";
            clr = clrLime;
            openPrice -= 5;
            break;
        case DOWN_13_UU:
            objName = "DOWN_13_UU_";
            openPrice -= 5;
            clr = clrLime;
            break;
    }
    string text = objName;
    objName += t;
    //StringAdd(objName, t);
    ObjectCreate(chart_ID, objName, OBJ_VLINE, 0, t, 0);
    ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
    ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 

    //StringAdd(objName, "text");
    //objName += "text";
    //ObjectCreate(chart_ID, objName, OBJ_TEXT, 0, t, openPrice+5);
    //ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
    //ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 
    //ObjectSetString(chart_ID,objName,OBJPROP_TEXT,text);
}

void drawClose(int type, datetime t, double openPrice){
    string objName = "undefined_";
    int clr = clrCadetBlue;

    switch(type){
        case CLOSE_BUY:
            objName = "-000-";
            clr = clrRed;
            break;
        case CLOSE_SELL:
            objName = "-xxx-";
            clr = clrRed;
            break;
    }
    StringAdd(objName, t);
    ObjectCreate(chart_ID, objName, OBJ_TEXT, 0, t, openPrice+5);
    ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
    ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 
    ObjectSetString(chart_ID,objName,OBJPROP_TEXT,objName);
    ObjectSetInteger(chart_ID,objName,OBJPROP_FONTSIZE,14);
}

void drawRemark(string text, datetime t, double openPrice){
    string objName = "text_";
    int clr = clrAquamarine;

    StringAdd(objName, t);
    ObjectCreate(chart_ID, objName, OBJ_TEXT, 0, t, openPrice+5);
    ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
    ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 
    ObjectSetString(chart_ID,objName,OBJPROP_TEXT,text);
    ObjectSetInteger(chart_ID,objName,OBJPROP_FONTSIZE,14);
}

// --------------------------------- public --------------------------------------

int strategyOpen1(int i, 
    double pre1Ma1,double pre2Ma1,double pre1Ma2,double pre2Ma2,double pre1Ma3,double pre2Ma3
){
    int type = 0;

    // int pi = 1;
    // double pre1Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi);
    // double pre2Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
    // double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi);
    // double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+pi+1);
    // double pre1Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+pi);
    // double pre2Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+pi+1);

    //当前1叉3
    if(
        (pre1Ma1-pre1Ma3>0) != (pre2Ma1-pre2Ma3>0)
    ){
        if(pre1Ma1>pre1Ma3){    //上叉
            if(pre1Ma1>pre2Ma1){
                if(pre1Ma3>pre2Ma3){
                    type = UP_13_UU;    //一致  1284, 662, 51.56%
                }else{
                    type = UP_13_UD;     //1310, 667, 50.92%
                }
            }else{
                type = UP_13_DD; //74, 37, 50%
            }
            
        }else{  //下叉
            if(pre1Ma1>pre2Ma1){
                type = DOWN_13_UU;   //49单，29盈单，比例：59.18%
            }else{
                if(pre1Ma3>pre2Ma3){
                    type = DOWN_13_DU;   //1399,632,45.18%
                    //return type = UP_13_UU; //比例低，是不是翻过来就ok了呢？    1377，678，49.24
                }else{
                    type = DOWN_13_DD;  //一致   1260,572,45.4%
                }
            }
        }
    }else{  //1叉2
      if(
         (pre1Ma1-pre1Ma2>0) != (pre2Ma1-pre2Ma2>0)
      ){
         
      }
    }
    
    //判断斜率
    double slope3 = (pre1Ma3-iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+3))/0.1;
    double slope1 = (pre1Ma2-iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+3))/0.1;
    
    //假设3水平
    if(fabs(slope3)<0.5){  //？？是否区分1叉2或叉3？
      if(fabs(slope1-slope3)>10){   //小山丘，1叉2
         //一致
      }else{   //窄幅震荡，以3为准
         if(type == UP_13_UD || type == DOWN_13_DU){   //1和3不一致的排除
            //return 0;
         }
      }
    }else{  //单边
      if(fabs(slope1-slope3)>5){//开口太大，危险
         //return 0;
      }
    }
    
    
    
    //up 1up-3up
    //up up-down
    //up down-down
   
    //down 1up-3up
    //down down-up
    //down down-down
   
    //flat 1up-3flat
    //flat 1down-3flat

    //用历史过滤
    

    return type;
    //return 0;
}

int strategyClose(int i, 
    double pre1Ma1,double pre2Ma1,double pre1Ma2,double pre2Ma2,double pre1Ma3,double pre2Ma3){
    return 0;
}

//============= 2 ===================
int strategyOpen(int i, 
    double pre1Ma1,double pre2Ma1,double pre1Ma2,double pre2Ma2,double pre1Ma3,double pre2Ma3
){
   int type = 0;
   double pre3Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+3);
   double pre4Ma1 = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i+4);
   double pre3Ma3 = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i+3);
   double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+3);
   if(
      pre1Ma1>pre1Ma2 && pre2Ma1<pre2Ma2
      && pre1Ma2<pre1Ma3
      && pre1Ma2>pre2Ma2
   ){
      type = UP_13_UU;
      
      string text = "";
      
      //ma1 不能加速向下
      if(
         pre1Ma1-pre2Ma1<pre2Ma1-pre3Ma1
      ){
         StringAdd(text, "1,");
      }
      
      //ma1 ma2 不能同时向下
      if(
         pre1Ma1<pre2Ma1 && pre1Ma2<pre2Ma2
      ){
         StringAdd(text, "2,");
      }
      
      //k线不能低于ma1
      if(
         Close[i+1]<pre1Ma1
      ){
         StringAdd(text, "3,");
      }
      
      //ma3不能加速向下
      if(
         pre1Ma3<pre2Ma3
         && (pre1Ma3-pre2Ma3)-(pre2Ma3-pre3Ma3)<0.01
      ){
         StringAdd(text, "4,");
      }
      
      //drawRemark(text, Time[i], Close[i]);
   }
   
   return type;
}