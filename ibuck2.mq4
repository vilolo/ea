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
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3
//--- plot ma3
#property indicator_label3  "ma3"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
//--- plot ma4
#property indicator_label4  "ma4"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrBlueViolet
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- input parameters
input int      ma1=5;
input int      ma2=16;
input int      ma3=30;
input int      ma4=60;

//--- indicator buffers
double         ma1Buffer[];
double         ma2Buffer[];
double         ma3Buffer[];
double         ma4Buffer[];

const long chart_ID = 0;
string tips[10];
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
    SetIndexBuffer(3,ma4Buffer);

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

    tips[0] = "tips";
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
   ma4Buffer[i] = iMA(Symbol(),0,ma4,0,MODE_SMA,PRICE_CLOSE,i);
}

bool isFirst = true;
int kpool = 80;
bool canTest = true;
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
    //if(Period() != 60) return rates_total;
    ObjectSet(objNameReferenceUp,1,close[0]+5);
    ObjectSet(objNameReferenceDown,1,close[0]-5);

    for(int i=0;i<rates_total;i++){
        drawMa(i);
        int type = 0;

        type = openStrategy(i);
        if(type>0){
            switch(type){
                case OOPEN_BUY:
                    drawVline(i, clrRed);
                    break;
                case OOPEN_SELL:
                    drawVline(i, clrLime);
                    break;
            }
            
            if(rates_total - i > kpool){
                //drawTrendLine(i, ma2);
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
    ObjectSetInteger(chart_ID,objName,OBJPROP_WIDTH,2); 
}

double curPrice = 0;
double point2Price = 0;
int point2Index = 0;
double point3Price = 0;
int point3Index = 0;
double point4Price = 0;
int point4Index = 0;
void drawTrendLine(int i, int ma){
    curPrice = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+1);
    bool isFindMin = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+2)<curPrice;

    for(int pi=2;pi<kpool;pi++){
        double temp0Price = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+pi-1);
        double temp1Price = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+pi);
        double temp2Price = iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+pi+1);
        
        if((temp2Price>temp1Price == isFindMin) && (temp1Price>temp0Price != isFindMin)){
            bool isTarget = true;
            for(int j=0;j<6;j++){
                if(iMA(Symbol(),0,ma,0,MODE_SMA,PRICE_MEDIAN,i+pi+2+j)>temp1Price != temp2Price>temp1Price){
                    isTarget = false;
                    break;
                }
            }
            if(isTarget){
                isFindMin = !isFindMin;
                if(point2Price == 0){
                    point2Price = temp1Price;
                    point2Index = pi;
                }else if(point3Price == 0){
                    point3Price = temp1Price;
                    point3Index = pi;
                }else if(point4Price == 0){
                    point4Price = temp1Price;
                    point4Index = pi;
                    break;
                }
            }
        }
    }
   
   if(point2Price>0){
        drawTrend(Time[i+1], curPrice, Time[i+point2Index], point2Price, clrRed);
        if(point3Price>0){
            drawTrend(Time[i+point2Index], point2Price, Time[i+point3Index], point3Price, clrLimeGreen);
            if(point4Price>0){
                drawTrend(Time[i+point3Index], point3Price, Time[i+point4Index], point4Price, clrBlue);
            }
        }
    }
}

int openStrategy(int i=0){
   int type = 0;
   
   type = openFunMa(i);
     
   return type;
}


//============= Ma  =============
int openFunMa(int i=0){
    int type = 0;
    
    return type;
}