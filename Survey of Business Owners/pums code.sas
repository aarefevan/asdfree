/*REFERENCE FILE*/
LIBNAME PUMS 'm:\econcen\07sbo\pums\final' ACCESS=READONLY;

/*RUN PROC CONTENTS TO GET A QUICK LOOK OF WHAT'S IN THE FILE*/
PROC CONTENTS DATA=PUMS.PUMS; RUN; 


/*CREATE THE MINORITY CATEGORIES FROM THE DIFFERENT RACE AND ETHNICITY FIELDS*/

DATA PUMS;
   SET PUMS.PUMS_SORTED (KEEP = FIPST SECTOR N07_EMPLOYER EMPLOYMENT_NOISY PAYROLL_NOISY RECEIPTS_NOISY 
                         RG TABWGT PCT1--RACE4);

   /*NARROW DOWN ETHNICITY AND RACE FIELDS BY PERCENTAGE FOR EACH OWNER*/
   IF INDEX(RACE1, 'B') OR INDEX(RACE1, 'A') OR 
      INDEX(RACE1, 'I') OR INDEX(RACE1, 'P') OR 
      INDEX(RACE1, 'S') OR NOT(ETH1 IN ('N', ' ')) 
   THEN PCT1_MINORITY = PCT1;
   ELSE PCT1_MINORITY = 0;

   IF INDEX(RACE2, 'B') OR INDEX(RACE2, 'A') OR 
      INDEX(RACE2, 'I') OR INDEX(RACE2, 'P') OR 
      INDEX(RACE2, 'S') OR NOT(ETH2 IN ('N', ' ')) 
   THEN PCT2_MINORITY = PCT2;
   ELSE PCT2_MINORITY = 0;

   IF INDEX(RACE3, 'B') OR INDEX(RACE3, 'A') OR 
      INDEX(RACE3, 'I') OR INDEX(RACE3, 'P') OR 
      INDEX(RACE3, 'S') OR NOT(ETH3 IN ('N', ' ')) 
   THEN PCT3_MINORITY = PCT3;
   ELSE PCT3_MINORITY = 0;

   IF INDEX(RACE4, 'B') OR INDEX(RACE4, 'A') OR 
      INDEX(RACE4, 'I') OR INDEX(RACE4, 'P') OR 
      INDEX(RACE4, 'S') OR NOT(ETH4 IN ('N', ' ')) 
   THEN PCT4_MINORITY = PCT4;
   ELSE PCT4_MINORITY = 0;

   /*SUM PERCENTAGES OF EACH OWNER*/
   PCT_MINORITY = SUM(PCT1_MINORITY,PCT2_MINORITY,PCT3_MINORITY,PCT4_MINORITY);

   /*DIVIDE OUT INTO SEPARATE GROUPS BASED ON THE PERCENTAGE, 51% OR MORE TO BE A MINORITY-OWNED BUSINESS*/
   IF PCT_MINORITY > 50 THEN TAB_MINORITY = 'M';
   ELSE IF PCT_MINORITY = 50 THEN TAB_MINORITY = 'E';
   ELSE TAB_MINORITY = 'N';

RUN;

/*SORT THE DATA BY STATE FOR THE NEXT STEP*/
PROC SORT DATA=PUMS; BY FIPST; RUN;

/*CREATE ANOTHER MACRO TO TABULATE THE FIRM TOTALS FOR EACH RANDOM GROUP BY MINORITY STATUS*/
%MACRO MINORITY;

%DO I = 1 %TO 10;

/*BREAKS DATASET INTO MINORITY, NONMINORITY, AND EQUALLY-OWNED BY RANDOM GROUP*/
DATA PUMS_MIN&I. PUMS_EQ&I. PUMS_NONMIN&I.;
   SET PUMS;
   IF TAB_MINORITY='M' AND RG = &I. THEN OUTPUT PUMS_MIN&I.;
   ELSE IF TAB_MINORITY='E' AND RG = &I. THEN OUTPUT PUMS_EQ&I.;
   ELSE IF TAB_MINORITY='N' AND RG = &I. THEN OUTPUT PUMS_NONMIN&I.;
   RUN;

/*THEN DETERMINE THE TOTAL NUMBER OF FIRMS BY SUMMING THE TABWGT BY STATE FOR STATE TOTALS OF EACH CATEGORY*/
DATA PUMS_MIN&I._2 (DROP = SECTOR N07_EMPLOYER EMPLOYMENT_NOISY--PCT_MINORITY);
   SET PUMS_MIN&I.;
   BY FIPST;
   RETAIN TOT_FIRM;
      IF FIRST.FIPST THEN DO;
         TOT_FIRM = 0;
      END;
   TOT_FIRM=TOT_FIRM + 10*sqrt(1-1/TABWGT)*tabwgt;
   IF LAST.FIPST THEN OUTPUT;
RUN;

DATA PUMS_EQ&I._2 (DROP = SECTOR N07_EMPLOYER EMPLOYMENT_NOISY--PCT_MINORITY);
   SET PUMS_EQ&I.;
   BY FIPST;
   RETAIN TOT_FIRM;
      IF FIRST.FIPST THEN DO;
         TOT_FIRM = 0;
      END;
   TOT_FIRM=TOT_FIRM + 10*sqrt(1-1/TABWGT)*tabwgt;
   IF LAST.FIPST THEN OUTPUT;
RUN;

DATA PUMS_NONMIN&I._2 (DROP = SECTOR N07_EMPLOYER EMPLOYMENT_NOISY--PCT_MINORITY);
   SET PUMS_NONMIN&I.;
   BY FIPST;
   RETAIN TOT_FIRM;
      IF FIRST.FIPST THEN DO;
         TOT_FIRM = 0;
      END;
   TOT_FIRM=TOT_FIRM + 10*sqrt(1-1/TABWGT)*tabwgt;
   IF LAST.FIPST THEN OUTPUT;
RUN;

%END;
%MEND MINORITY;

%MINORITY;

/*ONCE ALL OF THE SEPARATE DATASETS ARE CREATED, ROLL THEM BACK INTO ONE DATASET FOR CALCULATIONS*/
DATA PUMS4;
   SET PUMS_MIN1_2      PUMS_EQ1_2     PUMS_NONMIN1_2         
       PUMS_MIN2_2      PUMS_EQ2_2     PUMS_NONMIN2_2     
       PUMS_MIN3_2      PUMS_EQ3_2     PUMS_NONMIN3_2       
       PUMS_MIN4_2      PUMS_EQ4_2     PUMS_NONMIN4_2
       PUMS_MIN5_2      PUMS_EQ5_2     PUMS_NONMIN5_2
       PUMS_MIN6_2      PUMS_EQ6_2     PUMS_NONMIN6_2
       PUMS_MIN7_2      PUMS_EQ7_2     PUMS_NONMIN7_2
       PUMS_MIN8_2      PUMS_EQ8_2     PUMS_NONMIN8_2
       PUMS_MIN9_2      PUMS_EQ9_2     PUMS_NONMIN9_2
       PUMS_MIN10_2     PUMS_EQ10_2    PUMS_NONMIN10_2;
RUN;

/*USE THIS STEP TO FIND THE TOTAL SUM*/
PROC MEANS DATA=PUMS4 NOPRINT MISSING CHARTYPE;
   VAR TOT_FIRM;
   CLASS TAB_MINORITY FIPST;
   WAYS 2;
   OUTPUT OUT=PUMS4_1 SUM=CATMEAN;
RUN;

/*SORT TO PREPARE FOR FILE MERGING*/
PROC SORT DATA=PUMS4 NODUPKEY; BY FIPST TAB_MINORITY RG; RUN;
PROC SORT DATA=PUMS4_1 NODUPKEY; BY FIPST TAB_MINORITY; RUN;

DATA PUMS4_2;
   MERGE PUMS4(KEEP=FIPST RG TAB_MINORITY TOT_FIRM)
         PUMS4_1(KEEP=FIPST TAB_MINORITY CATMEAN);
   BY FIPST TAB_MINORITY;
RUN;

/*THIS STATEMENT FOLLOWS THE PROCEDURE DONE IN THE USERGUIDE TO FIND THE MEAN OF THE NONCERTAINTY RANDOM GROUP */
DATA PUMS4_3;
   SET PUMS4_2;
   /*CERTAINTY CASES SHOULD BE DROPPED BASED ON THE EARLIER DATASTEPS, BUT JUST 
   IN CASE THERE ARE ANY STRAGGLERS, MAKE SURE THAT THE RG IS NOT EQUAL TO ZERO.*/
   MNONCERT=CATMEAN/10;
   VAR_EST=1/10*(((TOT_FIRM-MNONCERT)**2)/9);    /*THIS FORMULA CAN BE FOUND ON PAGE 8 OF THE USER GUIDE*/                               
RUN;

/*USE PROC MEANS TO FIND THE VARIANCE*/
PROC MEANS DATA=PUMS4_3 NOPRINT MISSING CHARTYPE;
   VAR VAR_EST;
   CLASS TAB_MINORITY FIPST;
   WAYS 2;
   OUTPUT OUT=PUMS4_4 SUM=VARIANCE;
RUN;

/*USE A PROC MEANS TO FIND THE GRAND TOTAL COUNT FOR THE DIFFERENT GROUPS*/
PROC MEANS DATA=PUMS NOPRINT MISSING CHARTYPE;
      VAR TABWGT;
      CLASS TAB_MINORITY FIPST;
      WAYS 2;
      OUTPUT OUT=GRAND_TOTAL SUM=;
RUN;

/*MERGE THE TWO FILES WITH THE GRAND TOTAL ESTIMATES AND THE VARIANCE*/
DATA PUMS_FINAL;
   MERGE GRAND_TOTAL (KEEP = FIPST TAB_MINORITY TABWGT)
        PUMS4_4;
/*CALCULATE THE ADJUSTED VARIANCE AND THE RSE IN THIS STEP. NOTE: THE RSE IS GENERALLY ROUNDED TO THE NEAREST INTEGER*/
/*SEE PAGE 8 OF THE USER GUIDE*/
        ADJ_VAR=VARIANCE*1.992065;
        RSE=((SQRT(ADJ_VAR)/TABWGT)*100);
          ROUND_RSE=ROUND(RSE);
RUN;

/*THIS SORT ISN'T NECESSARY BUT IT MAKES THE TABLE EASIER TO READ*/
PROC SORT DATA = PUMS_FINAL; BY FIPST TAB_MINORITY; RUN;

/*CREATE FORMATS TO MAKE TABLE EASIER TO READ AT A GLANCE*/
PROC FORMAT;
VALUE $STATE
'01'='Alabama'
'02'='Alaska'
'04'='Arizona'
'05'='Arkansas'
'06'='California'
'08'='Colorado'
'09'='Connecticut'
'10'='Delaware'
'11'='District of Columbia'
'12'='Florida'
'13'='Georgia'
'15'='Hawaii'
'16'='Idaho'
'17'='Illinois'
'18'='Indiana'
'19'='Iowa'
'20'='Kansas'
'21'='Kentucky'
'22'='Louisiana'
'23'='Maine'
'24'='Maryland'
'25'='Massachusetts'
'26'='Michigan'
'27'='Minnesota'
'28'='Mississippi'
'29'='Missouri'
'30'='Montana'
'31'='Nebraska'
'32'='Nevada'
'33'='New Hampshire'
'34'='New Jersey'
'35'='New Mexico'
'36'='New York'
'37'='North Carolina'
'38'='North Dakota'
'39'='Ohio'
'40'='Oklahoma'
'41'='Oregon'
'42'='Pennsylvania'
'44'='Rhode Island'
'45'='South Carolina'
'46'='South Dakota'
'47'='Tennessee'
'48'='Texas'
'49'='Utah'
'50'='Vermont'
'51'='Virginia'
'53'='Washington'
'54'='West Virginia'
'55'='Wisconsin'
'56'='Wyoming'
'S1'='Alaska and Wyoming'
'S2'='Delaware and District of Columbia'
'S3'='North Dakota and South Dakota'
'S4'='Rhode Island and Vermont';
VALUE $MINORITY
'M'='Minority-Owned'
'E'='Equally Minority-and Nonminority-Owned'
'N'='Nonminority-Owned';
RUN;

/*APPLY FORMATS AND LABELLING AS NEEDED*/
DATA PUMS_FINAL2 (DROP = _TYPE_ _FREQ_ RSE);
   SET PUMS_FINAL;
   FORMAT FIPST $STATE. TAB_MINORITY $MINORITY.;
   TABWGT=ROUND(TABWGT);
   LABEL TAB_MINORITY="Race" 
         FIPST="Geography"
         TABWGT="Total Number of Firms"
         ADJ_VAR="Adjusted Variance"
         ROUND_RSE="Relative Standard Error";
   RUN;


