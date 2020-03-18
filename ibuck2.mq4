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

        type = strategyOpen(i);

        if(type>0){
            switch(type){
                case OOPEN_BUY:
                    drawVline(i, clrRed);
                    break;
            }
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
    string objName = "vline_";
    StringAdd(objName, Time[i]);
    ObjectCreate(chart_ID, objName, OBJ_VLINE, 0, Time[i], 0);
    ObjectSetInteger(chart_ID,objName,OBJPROP_TIMEFRAMES,OBJ_PERIOD_H1);
    ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr); 
}

//=========== strategy =================

int strategyOpen(int i){
    int type = 0;

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

    for(int pi=1;pi<kpool;pi++){
        kPrice = iMA(Symbol(),0,1,0,MODE_SMA,PRICE_CLOSE,i+pi);
        if(point3Price == 0){
            if(point2Price == 0){
                point2Price == kPrice;
            }else{
                if(curPrice-kPrice>0 == curPrice-point2Price>0){    //同向
                    if(fabs(curPrice-kPrice)>fabs(curPrice-point2Price)){
                        point2Price = kPrice;
                    }
                }else{
                    if(fabs(curPrice-kPrice)>fabs(curPrice-point2Price)){
                        if(fabs(curPrice-kPrice) > 5){
                            point3Price = kPrice;
                        }else{
                            point2Price = kPrice;
                        }
                    }
                }
            }
        }else{
            if(point4Price == 0){
                if(curPrice-kPrice>0 == curPrice-point3Price>0){
                    point2Price = kPrice;
                }else{
                    if(fabs(curPrice-kPrice)>fabs(curPrice-point2Price)){
                        if(fabs(curPrice-kPrice) > 5){
                            point3Price = kPrice;
                        }else{
                            point2Price = kPrice;
                        }
                    }
                }
            }
        }
    }

    type = type!=0?type:buyOpen(i);
    type = type!=0?type:sellOpen(i);

    return type;
}

int buyOpen(int i){
    int type = 0;

    return type;
}

int sellOpen(int i){
    int type = 0;
    return type;
}

