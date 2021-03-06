
!***************************************************************************************
!*
!* THIS PROGRAM COMPUTES BEACH PROFILE RESPONSE TO WAVE AND WATER LEVEL VARIATIONS 
!* INCLUDING THE FORMATION AND MOVEMENT OF MAJOR MORPHOLOGIC FEATURES SUCH AS
!* BARS AND BERMS. (variable grid version)
!*
!*+++++++++++++++++++++++++++++++++ RANDOM VERSION ONLY ++++++++++++++++++++++++++++++++
!*
!***************************************************************************************
Subroutine RUNModel(RunSimCode,NAME,OR1,OR2)
	Use ArrSize
	Use Memory, ONLY: K,RO,ROS,G,CEQ,CCORR,CRED,DX,DT,XSTART,D50,SRATIO,BI,CC,PI,LO,CEXO,&
		CEXP,AEXP,CEXR,EPS,BMAX,BAV,IELEV,DSURGE,PSURGE,LAMM,CC2,InitMemory,DoneMemory,FACTH
	Use Memoryq_u
	Use MemoryMain
	Use IOHandles, ONLY: fhiCFG,fhiPRI,fhiPRM,fhiHDB,fhiWAV,fhiELV,fhiWND, &
		fhoXVR,fhoPRC,fhoEXCEL,fhiANG,fhoLOG,fhoRPT,feiCFG,feiPRI,feiPRM,feiHDB
	Use QuantityUnits
	Use Timing
	Use FormatConst, ONLY: FM7000
	Implicit NONE
	Integer,intent(out)::RunSimCode
	Character(Len=*),intent(in):: NAME

	Real(8):: XREFELV,DRUMAX,TWAVL,TWAVH,HINL,TL,HINH,TH,TANGL,TANGH,ZINL,ZINH,TELVL,&
		TELVH,DSURGEL,DSURGEH,TWNDL,TWNDH,WL,ZWINDL,WH,ZWINDH,FIRSTRN,TRATIO,ARG,&
		CALCTIME,HBEG,T,DFS,TEMPC,TIME,XF(10),EFILL(10),R2,DMEAS,DTOT,RPERC, &
		LT,FTEMP,CGT,CNT,L1,CG1,CN1,ZIN,ZO,DXC,W,ZWIND,PEFAIL,WEFAIL,HFAIL,HO,&
		XELVI(3),XELVR(3),EDP(3),HIN,DTWAV,DTANG,TELEV,DTELV,DTWND,XLAND,DLAND,&
		XLBDUNE,DLBDUNE,XLCDUNE,DLCDUNE,XSCDUNE,DSCDUNE,XBERMS,DBERMS,XBERME,&
		DBERME,XFORS,DFORS,XBFS,XBFE,XSWALL,ZBEG,HOUT,REFELV, &
		ELV(3),LRU,hinc,SUMQ,vf,SCF,hnsr(12:248),DTR
	Integer:: I,J,NDT,ISTOP,NRSV,TCOMP(10),NWR,IANG,NFS,NRU,&
		NSWALL,NCOMP,IPP,IWAVE,IELV(3),IRAND,ISEED,IWIND,IMIN,ISWFAIL, &
		ICOMP,IBFILL,IDX,NGRID,TPIN,NFILL,ISWALL,NRMAX(3),ISWLIM,IHBOT,&
		NEDP1,NEDP2,NEDP3,ISTMIN,IZERO,IDRUMAX,NRSVM

	Character:: TITLE*70,MSGT*11,RPTTIME*8
	Character(Len=StrLenMax):: TmpStr
	
	LOGICAL:: GOOD,NOBREAK,SWFAIL,BLR,FLOOD,OVERWASH,OFFSHORE
	
	
!delete this stuff
Integer::OR1
Real(8)::OR2
!end delete this stuff

	Call InitMemory
	Call InitMemoryq_u
	Call InitArrSize
	Call InitTiming
	! Initialising control switches and misc variables
	FLOOD=.FALSE.;GOOD=.FALSE.
	IPP=0
	
	!*
	!* READ INPUT DATA SET NAME & DETERMINE MODEL CONFIGURATION
	!*
	CALL OPENOLD(fhiCFG,NAME,feiCFG)
	CALL INPUT(NAME,TITLE,UNITS,NDX,XSTART,IDX,DXC,NGRID,NDT,DT,NWR,&
		ICOMP,NCOMP,TCOMP,ELV,EDP,REFELV,K,EPS,LAMM,TEMPC,IWAVE,HIN,T,DTWAV,IANG,ZIN,&
		DTANG,DMEAS,IRAND,ISEED,RPERC,IELEV,TELEV,DTELV,IWIND,W,ZWIND,DTWND,TPIN,XLAND,&
		DLAND,XLBDUNE,DLBDUNE,XLCDUNE,DLCDUNE,XSCDUNE,DSCDUNE,XBERMS,DBERMS,XBERME,&
		DBERME,XFORS,DFORS,DFS,D50,BMAX,BAV,IBFILL,XBFS,XBFE,NFILL,XF,EFILL,ISWALL,&
		XSWALL,ISWFAIL,PEFAIL,WEFAIL,HFAIL,IHBOT,SCF,SREMGRID)
	If(ErrOcc)Then;RunSimCode=1;return;End If

	if(OR1>0) NDT=OR1
	if(OR2>0.) DT=OR2
	
	!*
	!*	Calibration coefficient for overwash & Allocating dynamic memory
	!*
	RRM=K*100.
	Allocate(DX(NDX),PriX(NDX),PriD(NDX),HBX(NDX),HBD(NDX),THMX(NDX),TEMX(NDX),&
		TDPMX(NDX),TDMX(NDX),TDMN(NDX),IHB(NDX),DI(NDX),DP(NDX),D(NDX),X(NDX),&
		Q(NDX+1),QP(NDX+1),H(NDX+1),E(NDX+1),DISS(NDX),XSV(NDX),DSV(NDX),&
		TETA(NDX),ATETA(NDX,4),DMX(NDX),DMN(NDX),HMX(NDX),EMX(NDX),&
		DPMX(NDX),ZW(NDX+1),VOLCH(NDX),brok(NDX),DSMO(NDX),EDHDX(NDX),DBOT(NDX))

	!*
	!* OPEN OUTPUT FILES AND WRITE HEADERS & WRITE CONFIGURATION TO REPORT FILE
	!*
	Call OpenOutputFiles(NAME,TITLE)
	Call ConfigReport(NDX,NDT,NWR,IANG,IWAVE,IRAND,ISEED,IWIND,ISWFAIL,ICOMP,IBFILL,&
		IDX,UNITS,NGRID,TPIN,ISWALL,IHBOT,T,DFS,TEMPC,DMEAS,RPERC,ZIN,DXC,W,ZWIND,&
		PEFAIL,WEFAIL,HFAIL,EDP,HIN,DTWAV,DTANG,TELEV,DTELV,DTWND,XSWALL,REFELV,ELV,&
		NDXV,WRI,DXV)
	!*
	!* ASSIGN UNITS CONVERSION FACTORS & PERFORM UNIT CONVERSION (TO S.I.)
	!*
	Call SetQuantityUnits;If(ErrOcc)Then;RunSimCode=2;Return;end if
	Call AdjustQuantityUnits(IBFILL,IDX,NGRID,NFILL,FACTH,DTR,DFS,XF,EFILL,DMEAS,&
		RPERC,ZIN,DXC,W,ZWIND,PEFAIL,WEFAIL,HFAIL,EDP,HIN,DTWAV,DTANG,TELEV,DTELV,&
		DTWND,XLAND,DLAND,XLBDUNE,DLBDUNE,XLCDUNE,DLCDUNE,XSCDUNE,DSCDUNE,XBERMS,DBERMS,&
		XBERME,DBERME,XFORS,DFORS,XBFS,XBFE,XSWALL,FACTL,REFELV,ELV,OFFSHORE,DXV)
	!*
	!*  ASSIGN GRID CELL WIDTHS TO EACH CELL
	!*
	IF(IDX==0)THEN
		DX=DXC
	ELSE
		CALL VARGRID(NDX,DXV,NDXV,DX)
	End If
	!*
	!* DETERMINE DEEP WATER WAVE LENGTH FOR CONSTANT WAVE CONDITION
	!*
	IF(IWAVE==0)THEN
		HINC=HIN
		LO=1.5613*T**2
	End If
	!*
	!* ASSIGN DSURGE IF TOTAL WATER ELEVATION IS CONSTANT
	!*
	IF(IELEV==0) DSURGE=TELEV
	!*
	!* READ INITIAL PROFILE DEPTHS IN Subroutine InitialProfile (POSITIVE BELOW
	!* INITIAL SWL AND NEGATIVE ABOVE INITIAL SWL)
	!*
	IF (TPIN==1) THEN
		CALL OPENOLD(fhiPRI,NAME,feiPRI)
		CALL HEADER(fhiPRI)
		If(ErrOcc)Then;RunSimCode=3;return;End IF
	End If

	CALL InitialProfile(TPIN,DI,X,NDX,XLAND,DLAND,XLBDUNE,DLBDUNE,XLCDUNE,DLCDUNE,XSCDUNE,&
		DSCDUNE,XBERMS,DBERMS,XBERME,DBERME,XFORS,DFORS,FACTL)
	if(ERROCC)Then;RunSimCode=4;return;End If
	IF (ICOMP==1) CALL OPENOLD(fhiPRM,NAME,feiPRM)
	!*
	!* CHECK FOR BEACH FILL 
	!*
	IF(IBFILL==1) THEN
		CALL BCHFILL(XBFS,XBFE,NFILL,XF,EFILL,NDX,X,DI,FACTV,VUNITS)
		if(ERROCC)Then;RunSimCode=5;return;End If
	End If
	!*
	!* CHECK FOR HARD BOTTOMS
	!*
	IHB=0 !* INITIALIZE EXPOSED HARD BOTTOM INDICATOR ARRAY
	IF(IHBOT==1)THEN
		CALL OPENOLD(fhiHDB,NAME,feiHDB)
		CALL HEADER(fhiHDB)
		If(ErrOcc)Then;RunSimCode=6;return;End IF
	!*
	!* READ HARD BOTTOM ELEVATIONS AND GENERATE VALUES ON THE COMPUTATIONAL GRID
	!*
		CALL HBELEV(NDX,X,DI,DBOT,FACTL)
		if(ERROCC)Then;RunSimCode=7;return;End If
		
	End If
	!*
	!* FIND INITIAL LOCATION OF 3 ELEVATIONS TO MONITOR AND REFERENCE ELEVATION
	!* 
	Call InitialContourLocations(IELV,ELV,XELVI,XELVR,NRMAX,ErrOcc,REFELV,XREFELV)
	!*
	!* ESTIMATE INITIAL FORESHORE SLOPE FOR RUNUP CALC.
	!*  -- => ASSIGN BI=0.1 RADIANS 
	!*
	BI=.1
	!*
	!* THE SEAWALL IS LOCATED IN NODE NO. NSWALL
	!*
	NSWALL=1
	ErrOcc=.TRUE.
	IF(ISWALL==1) THEN
		DO I=1,NDX
			IF(XSWALL<=X(I)) THEN
				NSWALL=I
				ErrOcc=.FALSE.
				Exit
			End If
		End Do
		If(ErrOcc)Then
			Call WriUFLOG('ERROR: INVALID SEAWALL LOCATION')
		End If
	End If
	ErrOcc=.FALSE.
	!*
	!* WRITE NUMBER OF GRID CELLS AND POSITION OF GRID CELLS
	!*
	CALL WRTX(fhoPRC,NDX,LUNITS,X,FACTL)
	CALL WRTX(fhoXVR,NDX,LUNITS,X,FACTL)
	!*
	!* WRITE INITIAL PROFILE (INCLUDING FILL)
	!*
	CALL DSHLN(fhoPRC)
	WRITE(fhoPRC,'("INITIAL PROFILE ELEVATION ",A)') Trim(LUNITS)
	WRITE(fhoPRC,FM7000) (-DI(I)/FACTL,I=1,NDX)
	!*
	!* INITIALIZE ARRAYS
	!*
	Q=0.0;QP=0.0;D=DI;DP=DI;DMX=DI;TDMX=0;DMN=DI;TDMN=0;HMX=0.0;THMX=0;EMX=-9999.
	TEMX=0;DPMX=0.0;TDPMX=0;NEDP1=0;NEDP2=0;NEDP3=0;drumax=-1000.;ISTMIN=NDX;DBOT=0.0
	!*
	!* INITIALIZE SEAWALL FAILURE PARAMETERS
	!*
	H(NSWALL)=0
	H(NSWALL+1)=0
	E(NSWALL)=0
	!*
	!* DETERMINE COEFFICIENTS TO BE USED IN KINEMATIC VISCOSITY
	!* CALCULATION
	!*
	CALL KVISC(TETA,ATETA)
	!*
	!* DETERMINE THE FALL VELOCITY
	!*
	CALL FALVEL(TEMPC,TETA,ATETA,VF) 
	!*
	!* READ FIRST TWO VALUES FROM VARIABLE DATA FILES FOR INTERPOLATION
	!*
	Call CheckTemporalInfo(NDT,IANG,IWAVE,IWIND,TWAVL,TWAVH,HINL,TL,HINH,TH,TANGL,&
		TANGH,ZINL,ZINH,TELVL,TELVH,DSURGEL,DSURGEH,TWNDL,TWNDH,WL,ZWINDL,WH,ZWINDH,DTWAV,&
		DTANG,DTELV,DTWND,RunSimCode,NAME)
		
	CALL SEED(ISEED)
	CALL RANDOM(FIRSTRN)
	FIRSTRN=FIRSTRN*0
	SWFAIL=.FALSE.
	!Call WriUFSCROnly('RUN: '//trim(TITLE))
	!*
	!* Initial array for determining Hs of unbroken waves
	!* (for random wave simulation ONLY)
	!*
	Call HNSRATIO(hnsr)
	if(CHECKONLY)Then
		RunSimCode=0
		Return
	End If
	StatusUpdate=nint(NDT/100.0-1)
	!*
	!* MAIN CALCULATION LOOP IN TIME
	!* -----------------------------
	!*
	DO I=1,NDT
		!*
		!*
		!* OBTAIN WAVE AND WATER LEVEL DATA AT CURRENT TIME STEP')
		!*
		!*
		NOBREAK=.FALSE.
		TIME=Real(I)*DT
		Call ReadTemporalInfo(IANG,IWAVE,IWIND,OFFSHORE,FACTH,DTR,TWAVL,TWAVH,&
			HINL,TL,HINH,TH,TANGL,TANGH,ZINL,ZINH,TELVL,TELVH,DSURGEL,DSURGEH,TWNDL,&
			TWNDH,WL,ZWINDL,WH,ZWINDH,TRATIO,T,TIME,ZIN,W,ZWIND,HIN,DTWAV,DTANG,DTELV&
			,DTWND,FACTL)

		!*
		!*
		!* Preprocessing wave information')
		!*
		!*
		Call PreProcessWaves(IWAVE,IRAND,OFFSHORE,ARG,HBEG,T,DMEAS,DTOT,RPERC,LT,FTEMP,&
			CGT,CNT,L1,CG1,CN1,HO,HIN,HOUT,hinc,D(NDX),ZIN,ZBEG,ZO)
		!*
		!*
		!* ADD THE WATER LEVEL INCREASE')
		!*
		!*
		DO J=1,NDX
			D(J)=D(J)+DSURGE
			DP(J)=DP(J)+PSURGE
		End Do
		!* 
		!*
		!* SMOOTH PROFILE ETC & WAVE HEIGHT VARIATION')
		!*
		!*
		msgt='[RANDOM_WV]'
		CALL DOMSMO(NDX,DX,D,HO,DSMO,nswall)
		!*
		!* DOMSMO - done')
		!*
		CALL WAVRAN(DX,NSWALL,HBEG,T,ZBEG,DSMO,H,E,ISTOP,ZW,DISS,BROK,X,&
			ISWLIM,hnsr,w,zwind,d)
		!*
		!*
		!* CHECK FOR SEAWALL FAILURE (BASED ON HRMS FOR RANDOM WAVES)')
		!*
		!*
		Call SeaWallFailureCheck(NDX,I,ISWALL,ISWFAIL,ISTOP,NSWALL,HFAIL,H,E,DSURGE,WEFAIL,SWFAIL)
		!*
		!*
		!* Include SETUP IN DSMO BEFORE CALCULATING TRANSPORT RATES')
		!*
		!*
		Call AddSetUpToDepth(NDX,ISTOP,DSMO,E)
		!*
		!* COMPUTE SLOPE TERM IN TRANSPORT RATE CALCULATIONS')
		!* 
		EDHDX=0.0
		Call SlopeTransPort(NDX,istop,NSWALL,EDHDX,D,DX)
		!*
		!*
		!* CROSS-SHORE TRANSPORT RATES (SURF ZONE AND OFFSHORE ZONE)')
		!* TRANSPORT DIRECTION AND WEIGHING Function')
		!*
		!*
		CALL TRRAN(NDX,HO,ZO,T,VF,X,DSMO,ISTOP,ZW,DISS,BROK,EDHDX,Q,ISWLIM)
		!*
		!*
		!* CROSS-SHORE TRANSPORT RATES IN THE SWASH ZONE')
		!*
		!* 
		CALL SWSHDOM(NDX,X,D,E,HO,NSWALL,DFS,NRU,NFS,IMIN,BLR,ISWALL,IZERO,&
			LRU,zo,drumax,i,idrumax,brok)
		CALL EXRUN(NRU,NFS,Q,IMIN,X,D,OVERWASH,IZERO,LRU,BLR,dfs)
		Q(nru)=0.0
		! ALLOW SAND TO MOVE OFF GRID IF SREMGRID IS TRUE (THIS IS SET IN TRRAN TRMON)
		! ADDED BY NCK ON 11/18/95
		If(SREMGRID) Q(NDX+1)=0.0

		Call CONSAN(NDX,NRU,D,Q,DP,QP,NSWALL,PEFAIL,ISWFAIL,SWFAIL,time,istop,iswall,factl,lunits,&
			&IHBOT,IHB,DBOT,SCF,I)

		!*
		!*
		!* COMPARE SIMULATION RESULTS WITH MEASUREMENTS')
		!*
		!*
		Call CompareWithMeasurements(NDX,NRSV,TCOMP,NCOMP,IPP,ICOMP,NRSVM,GOOD,&
			RunSimCode,R2,FACTL,SUMQ,I)	
		!*
		!*
		!* WRITE RESULTS TO UNIT fhoXVR AND fhoPRC')
		!*
		!*
		Call WriteResults(NWR,I,NDX,WRI,D,DI,X,H,E,DSURGE,NRMAX,ELV,XELVR,&
				ISTOP,NDT,ISTMIN,IELV)
		!*
		!*
		!* ZERO OUT TRANSPORT RATES & UPDATE SURGE LEVEL')
		!*
		!*
		Q=0.
		PSURGE=DSURGE
		GOOD=.FALSE.
		!*
		!*
		!* Report status of simulation to the screen')
		!*
		!*
		Call LoopStatus(MSGT,FLOOD,OVERWASH,BLR,I,NDT)

	End Do
	!*
	!* Post process results
	!*
	Call PostProcessingResults(NDX,ISTMIN,RunSimCode,D,DX,DI,VOLCH,X,NRSV,IELV,&
		ICOMP,NEDP1,NEDP2,NEDP3,XREFELV,DRUMAX,XELVI,XELVR,EDP,ELV,SUMQ)
	
	!*
	!* Simulation completed, report time to user, set exit code, clear memory
	!* and close all files.
	!*
	Call TimeTake(CALCTIME,RPTTIME)
	WRITE(TmpStr,'("+Processing is completed, time taken was ",F0.1,X,A)') &
		CALCTIME,Trim(RPTTIME)
	Call WriScr(TmpStr)
	Write(TmpStr,'("Normal simulation completion in ",F0.1," ",A)') CALCTIME,Trim(RPTTIME)
	Call WriUFLOGRPT(TmpStr)
	RunSimCode=0
	Call DoneMemoryq_u
	Call DoneMemoryMain
	Call DoneMemory
	Call CloseAllFiles
	Return
End Subroutine RUNModel

