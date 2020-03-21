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

//--- input parameters
input int      ma1=5;
input int      ma2=10;
input int      ma3=28;

//--- indicator buffers
double         ma1Buffer[];
double         ma2Buffer[];
double         ma3Buffer[];

const long chart_ID = 0;
string tips[20];
string objNameReferenceUp = "referenceLineUp";  //参考线
string objNameReferenceDown = "referenceLineDown";

#define OOPEN_BUY 1
#define OOPEN_SELL 2
#define CLOSE_BUY 11
#define CLOSE_SELL 12

int OnInit()
{
    SetIndexBuffer(0,ma1Buffer);
    SetIndexBuffer(1,ma2Buffer);
    SetIndexBuffer(2,ma3Buffer);

    long handle=ChartID(); 
    if(handle>0)
    { 
        ChartSetInteger(handle, CHART_SCALE, 3);
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

    tips[0] = "excellent";
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

void drawMa(int i){
   ma1Buffer[i] = iMA(Symbol(),0,ma1,0,MODE_SMA,PRICE_CLOSE,i);
   ma2Buffer[i] = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i);
   ma3Buffer[i] = iMA(Symbol(),0,ma3,0,MODE_SMA,PRICE_CLOSE,i);
}


int tempi;
bool isFirst = true;
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
        int type = 0;

        type = openStrategy(i);

        if(type>0){
            switch(type){
                case OOPEN_BUY:
                    drawVline(i, clrRed);
                    break;
            }

            drawMyTrendLine(i);
        }
    }

    return rates_total;
}

void drawText(int i, string text, int clr = clrRed){
    string objName = "text_";
    StringAdd(objName, Time[i]);
    ObjectCreate(chart_ID, objName, OBJ_TEXT, 0, Time[i], Open[i]+5);
    ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
    ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 
    ObjectSetString(chart_ID,objName,OBJPROP_TEXT,text);
    ObjectSetInteger(chart_ID,objName,OBJPROP_FONTSIZE,12);
}

void drawVline(int i, int clr = clrRed){
    string objName = "vline_"+Time[i];
    ObjectCreate(chart_ID, objName, OBJ_VLINE, 0, Time[i], 0);
    ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
    ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 
}

void drawTrend(datetime time1, double price1, datetime time2, double price2, int clr = clrRed){
    string objName = "trend_"+time1+"_"+time2;
    ObjectCreate(chart_ID, objName, OBJ_TREND, 0, time1,price1,time2,price2);
    ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
    ObjectSetInteger(chart_ID,objName,OBJPROP_RAY_RIGHT,false); 
    ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 
}

void drawMyTrendLine(int i){
    //确定前期情况，鱼尾巴甩动一样感知，向前找转折点，与当前点相减正负不一致并且大于10的点算个转折点，4点3条折线
    //当前点过来的第二个点是不是比较特殊，不一定与当前点差很远
    double point2Price=0;
    double point2Gap=0;
    int point2Position=0;
    double point3Price=0;
    double point3Gap=0;
    int point3Position=0;
    double point4Price=0;
    double point4Gap=0;
    int point4Position=0;

    double kPrice;
    double curPrice = iMA(Symbol(),0,1,0,MODE_SMA,PRICE_CLOSE,i);

    //记录最大最小看最大最小，谁先后面轮空多少根
    double compareCount = 6;
    double tempMax = 0;
    double tempMin = 0;
    double tempMaxCount = 0;
    double tempMinCount = 0;
    int tempMaxIndex = 0;
    int tempMinIndex = 0;
    double tempPrice;
    int tempIndex;
    double previousFirmPrice;   //上一个确定的价格

    for(int pi=1;pi<kpool;pi++){
        tempMaxCount++;
        tempMinCount++;
        
        if(point3Price == 0){
            previousFirmPrice = curPrice;
        }else if(point4Price == 0){
            previousFirmPrice = point2Price;
        }else{
            previousFirmPrice = point3Price;
        }

        kPrice = iMA(Symbol(),0,1,0,MODE_SMA,PRICE_CLOSE,i+pi);
        if(previousFirmPrice-kPrice>0){  //找最小
            if(tempMin==0 || tempMin>kPrice){
                tempMin = kPrice;
                tempMinCount = 0;
                tempMinIndex = pi;
            }
        }else{
            if(tempMax==0 || tempMax<kPrice){
                tempMax = kPrice;
                tempMaxCount = 0;
                tempMaxIndex = pi;
            }
        }

        if(
            (tempMaxCount>compareCount || tempMinCount>compareCount) &&
            (tempMax>0 && tempMin>0)
        ){
            if(tempMaxCount>compareCount){
                tempMaxCount = 0;
                tempPrice = tempMax;
                tempIndex = tempMaxIndex;
            }else{
                tempMinCount = 0;
                tempPrice = tempMin;
                tempIndex = tempMinIndex;
            }

            if(point2Price == 0){
                point2Price = tempPrice;
                point2Position = tempIndex;
            }else{
                if(point3Price == 0){
                    point3Price = tempPrice;
                    point3Position = tempIndex;
                }else{
                    point4Price = tempPrice;
                    point4Position = tempIndex;
                }
            }
        }
    }

    if(point2Price>0){
        drawTrend(Time[i], curPrice, Time[i+point2Position], point2Price);
        if(point3Price>0){
            drawTrend(Time[i+point2Position], point2Price, Time[i+point3Position], point3Price);
            if(point4Price>0){
                drawTrend(Time[i+point3Position], point3Price, Time[i+point4Position], point4Price);
            }
        }
    }

    if(point4Price>point2Price){
        drawText(i, "xxx");
    }
}

//=========== strategy =================

int openStrategy(int i){
    int type = 0;

    type = buyOpen(i);
    type = type!=0?type:sellOpen(i);

    return type;
}

//参考的是一小撮k线，不是2，3根
//或者对比与短均线关系
int buyOpen(int i){
    int type = 0;

    double pre1Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+1);
    double pre2Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+2);
    double pre3Ma2 = iMA(Symbol(),0,ma2,0,MODE_SMA,PRICE_CLOSE,i+3);

    if(
        pre1Ma2<Close[i+1]
        && pre2Ma2>Close[i+2]
        && pre3Ma2>Close[i+3]
    ){
        type = OOPEN_BUY;
        
        string text = "";
        
        //ma1 不能加速向下
        // if(
        //     pre1Ma1-pre2Ma1<pre2Ma1-pre3Ma1
        // ){
        //     StringAdd(text, "1,");
        // }
        
        drawText(i, text);
    }

    return type;
}

int sellOpen(int i){
    int type = 0;
    return type;
}

