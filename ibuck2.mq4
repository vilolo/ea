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

int OnInit()
{
    SetIndexBuffer(0,ma1Buffer);
    SetIndexBuffer(1,ma2Buffer);
    SetIndexBuffer(2,ma3Buffer);

    long handle=ChartID(); 
    if(handle>0) // If it succeeded, additionally customize 
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

