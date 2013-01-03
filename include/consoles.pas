unit consoles;

interface

uses Windows, Classes, SysUtils;

const

     Black        = 0;
     Blue         = 1;
     Green        = 2;
     Cyan         = 3;
     Red          = 4;
     Magenta      = 5;
     Brown        = 6;
     LightGray    = 7;
     // Foreground colors
     DarkGray     = 8;
     LightBlue    = 9;
     LightGreen   = 10;
     LightCyan    = 11;
     LightRed     = 12;
     LightMagenta = 13;
     Yellow       = 14;
     White        = 15;

     Blink        = 128;

     ERROR_CMDLINE_PARAM:WideString = #10#10#10;

type
     TConsoleWindowPosition = (cwDefault,cwLeft,cwRight,cwTop,cwBottom,cwDesktopCenter,cwScreenCenter);

     TCommandLineParameter = class(TCollectionItem)
     private
      FOwner:TObject;
      FSource:WideString;
      FParamName,FParamValue:WideString;
     private
      procedure parseit(v:WideString=''); 
     public
      constructor Create(aOwner:TObject;aCollection:TCollection);reintroduce;virtual;
      destructor Destroy;override;

      property index;
      property name:WideString read FParamName;
      property value:WideString read FParamValue;
     end;

     TCommandLine = class(TPersistent)
     private
      FList:TCollection;
      FCommandLine:WideString;
      FHandle:HWND;
    function getFlag(value: WideString): boolean;
     private
      function getCount: integer;
      function getItem(value: WideString): WideString;
      procedure parseParams(v:WideString);virtual;
     public
      constructor Create(aHandle:HWND);virtual;
      destructor Destroy;override;

      property cmdline:WideString read FCommandLine;
      property flag[value:WideString]:boolean read getFlag;
      property key[value:WideString]:WideString read getItem;default;
      property parametercount:integer read getCount;
     end;

     TConsoleApplication = class(TPersistent)
     private
      FHandle:HWND;
      FExitCode:DWORD;
      FCommandLine:TCommandLine;
      FPosition:TConsoleWindowPosition;
      FOnDestroy,FOnTerminate:TNotifyEvent;
     private
      procedure setTextPositionXY(X,Y:SmallInt);
     private
      procedure setPosition(aPosition:TConsoleWindowPosition);
      procedure setTitle(aTitle:WideString);
      function getTitle:WideString;
     protected
      function IntOnCloseQuery(const aType:DWORD):boolean;virtual;
      function IntOnTerminate(const aType:DWORD):boolean;virtual;
     protected
      procedure InitDefaultConsole;virtual;
      procedure IntTerminateProcess(Sender:TObject);virtual;
      procedure IntOnDestroy(Sender:TObject);virtual;
     protected
      function processMessage(var msg:TMsg):boolean;virtual;
     public
      constructor Create(aTitle:WideString;aPosition:TConsoleWindowPosition=cwDesktopCenter);virtual;
      destructor Destroy;override;

      procedure processMessages;

      function setFullScreen(aFullScreen:boolean):boolean;
      procedure clearText;

      procedure SetTextColor(aColor:Byte);
      procedure SetBackgroundColor(aColor:Byte);
      procedure textpos(x,y:SmallInt);

      procedure NormalVideo;
      procedure HighVideo;
      procedure LowVideo;

      function disableInput:DWORD;
      function enableInput:DWORD;

      procedure showCursor(aShow:boolean);
      function output(v:WideString):TConsoleApplication;
      function newline:TConsoleApplication;
      function anykey:TConsoleApplication;


      property handle:HWND read FHandle;
      property title:WideString read getTitle write setTitle;
      property position:TConsoleWindowPosition read FPosition write setPosition;
      property exitCode:DWORD read FExitCode write FExitCode;
      property commandline:TCommandLine read FCommandLine;
     public
      property OnDestroy:TNotifyEvent read FOnDestroy write FOnDestroy;
      property OnTerminate:TNotifyEvent read FOnTerminate write FOnTerminate;
     end;

     procedure hide;
     function ToMethod(aCode:Pointer;aData:Pointer=nil):TMethod;stdcall;


implementation

uses Messages, WideStrUtils, fileTools;

var _self:TConsoleApplication; // for console handler

{ TCommandLineParameter }

constructor TCommandLineParameter.Create(aOwner: TObject; aCollection: TCollection);
begin
 inherited Create(aCollection);
 FOwner:=aOwner;
 FParamName:='';
 FParamValue:='';
end;

destructor TCommandLineParameter.Destroy;
begin
 inherited Destroy;
end;

procedure PathUnquoteSpacesW(lpsz:PWideChar);stdcall; external 'shlwapi.dll';
procedure TCommandLineParameter.parseit(v: WideString);
var i1,i2:integer;
begin
 if trim(v)<>'' then FSource:=v;
 if trim(FSource)='' then Exit; // impossible situation in fact
 i1:=pos('-',FSource);
 i2:=pos(':',FSource);
 if i2=0 then // flag
  begin
   if i1>0 then FParamName:=copy(FSource,i1+1,length(FSource)-i1);
   FParamName:=trim(FParamName);
  end
 else
  begin // parameter
   if i1>=0 then
    begin
     FParamName:=copy(FSource,i1+1,i2-i1-1);
     FParamName:=trim(FParamName);
     FParamValue:=copy(FSource,i2+1,Length(FSource)-i2);
     FParamValue:=trim(FParamValue);
    end;
  end;
end;

{ TCommandLine }

function GetParamStrW(p:PWideChar;var v:WideString):PWideChar;
var
 i,len:integer;
 start,s,q:PWideChar;
begin

 while true do
  begin
   while (p[0]<>#0) and (p[0]<=' ') do p:=CharNextW(p);
   if (p[0]='"') and (p[1]='"') then inc(p,2) else break;
  end;

 len:=0;
 start:=p;
 while p[0]>' ' do
  begin
   if p[0]='"' then
    begin
     p:=CharNextW(p);
     while (p[0]<>#0) and (p[0]<>'"') do
      begin
       q:=CharNextW(p);
       inc(len,q-p);
       p:=q;
      end;
     if p[0]<>#0 then p:=CharNextW(p);
    end
   else
    begin
     q:=CharNextW(p);
     inc(len,q-p);
     p:=q;
    end;
  end;

 setLength(v,len);
 p:=start;
 s:=pointer(v);
 i:=0;
 while p[0]>' ' do
  begin
   if p[0]='"' then
    begin
     P:=CharNextW(p);
     while (p[0] <> #0) and (p[0] <> '"') do
      begin
       q:=CharNextW(p);
       while p<q do
        begin
         s[i]:=p^;
         inc(p);
         inc(i);
        end;
      end;
     if p[0]<>#0 then p:=CharNextW(p);
    end
   else
    begin
     q:=CharNextW(p);
     while p<q do
      begin
       s[i]:=p^;
       inc(p);
       inc(i);
      end;
    end;
  end;
 Result:=p;
end;

function ParamWideCount(path:PWideChar):integer;
var
 p:PWideChar;
 s:WideString;
begin
 p:=path;
 Result:=0;
 while true do
  begin
   p:=GetParamStrW(p,s);
   if s='' then break;
   inc(Result);
  end;
end;

function ParamWideStr(path:PWideChar;index:integer):WideString;
var p:PWideChar;
begin
 Result :='';
 p:=path;
 while true do
  begin
   p:=GetParamStrW(p,Result);
   if (index=0) or (Result='') then break;
   dec(index);
  end;
end;

constructor TCommandLine.Create(aHandle: HWND);
var
 p:PWideChar;
 sz:DWORD;
 FRaw:WideString;
begin
 FHandle:=aHandle;
 FList:=TCollection.Create(TCommandLineParameter);

 FCommandLine:=WideString(windows.GetCommandLineW);
 FRaw:=FCommandLine;
 if pos(':\',FCommandLine)=0 then // relative path
  begin
   sz:=fileTools.WideLastDelimiter('\',FCommandLine);
   FCommandLine:=copy(FCommandLine,integer(sz)+1,length(FCommandLine)-integer(sz));
   if pos('"',trim(FRaw))=1 then FCommandLine:='"'+FCommandLine; //repairing "
  end;

 sz:=1024*SizeOf(WideChar); // in case of environment vars like %TEMP%
 p:=PWideChar(AllocMem(sz));
 if windows.ExpandEnvironmentStringsW(PWideChar(FCommandLine),p,sz)>0 then FCommandLine:=WideString(p);
 FreeMem(p,sz);
 
 if trim(FCommandLine)<>'' then parseParams(FCommandLine);
end;

destructor TCommandLine.Destroy;
begin
 if Assigned(FList) then FreeAndNil(FList);
 inherited Destroy;
end;

function TCommandLine.getCount: integer;
begin
 if Assigned(FList) then Result:=FList.count else Result:=0;
end;

function TCommandLine.getFlag(value: WideString): boolean;
var i:integer;
begin
 Result:=False;
 value:=trim(WideStrUtils.WideLowerCase(value));
 if value='' then Exit; 
 if not Assigned(FList) then Exit;
 for i:=0 to FList.Count-1 do
  if value=trim(WideStrUtils.WideLowerCase(TCommandLineParameter(FList.Items[i]).name)) then
   begin
    Result:=True;
    Break;
   end;
end;

function TCommandLine.getItem(value: WideString): WideString;
var i:integer;
begin
 Result:=ERROR_CMDLINE_PARAM; // error mark mean not found
 value:=trim(WideStrUtils.WideLowerCase(value));
 if value='' then Exit; 
 if not Assigned(FList) then Exit;
 for i:=0 to FList.Count-1 do
  if value=trim(WideStrUtils.WideLowerCase(TCommandLineParameter(FList.Items[i]).name)) then
   begin
    Result:=TCommandLineParameter(FList.Items[i]).value;
    Break;
   end;
end;

procedure TCommandLine.parseParams(v: WideString);
var
 i,c:DWORD;
 itm:TCommandLineParameter;
begin
 if not Assigned(FList) then Exit;
 FList.Clear;
 c:=ParamWideCount(PWideChar(FCommandLine));
 if c>1 then
  for i:=1 to c-1 do
   begin
    itm:=TCommandLineParameter(FList.Add);
    itm.FSource:=ParamWideStr(PWideChar(FCommandLine),i);
    itm.parseit;
   end;
end;

{ TConsoleApplication }

function ToMethod(aCode:Pointer;aData:Pointer=nil):TMethod;stdcall;
begin
 Result.Code:=aCode;
 Result.Data:=aData;
end;

function consoleProcHandler(CtrlType:DWORD):BOOL;stdcall;far;
begin
 Result:=False; // default processing
 case CtrlType of
  CTRL_LOGOFF_EVENT,CTRL_SHUTDOWN_EVENT,CTRL_CLOSE_EVENT:if Assigned(_self) then
                                                          begin
                                                           System.ExitCode:=_self.ExitCode;
                                                           Result:=not _self.IntOnCloseQuery(CtrlType);
                                                           windows.ExitProcess(_self.ExitCode);
                                                          end else windows.ExitProcess(DWORD(-1));
  CTRL_BREAK_EVENT,CTRL_C_EVENT:if Assigned(_self) then
                                                    begin
                                                     System.ExitCode:=_self.ExitCode;
                                                     Result:=not _self.IntOnTerminate(CtrlType);
                                                     windows.ExitProcess(_self.ExitCode);
                                                    end else windows.ExitProcess(DWORD(-1));
  else Result:=False;
 end;
end;

function GetConsoleWindow:HWND;stdcall; external kernel32 name 'GetConsoleWindow';

constructor TConsoleApplication.Create(aTitle: WideString; aPosition: TConsoleWindowPosition);
begin
 _self:=Self;
 FOnDestroy:=nil;
 FOnTerminate:=nil;

 FHandle:=GetConsoleWindow;
 FCommandLine:=TCommandLine.Create(FHandle);

 windows.SetConsoleTitleW(PWideChar(aTitle));
 if aPosition<>cwDefault then setPosition(aPosition);
 FExitCode:=0;

 InitDefaultConsole;
 windows.SetConsoleCtrlHandler(@consoleProcHandler,true);
end;

procedure TConsoleApplication.clearText;
var
 sp:TCoord;
 buf:TConsoleScreenBufferInfo;
 l,ww:DWORD;
 i:integer;
 r:TRect;
 tw:TSmallRect;
 textAttr:Byte;
begin
 GetWindowRect(GetConsoleWindow,r);
 if not GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE),buf) then Exit;

 tw.Left:=0;
 tw.Top:=0;
 tw.Right:=buf.dwSize.X-1;
 tw.Bottom:=buf.dwSize.Y-1;

 textAttr:=buf.wAttributes and $FF;

 if (tw.left=0) and (tw.top=0) and (tw.right=buf.dwSize.x-1) and (tw.bottom=buf.dwSize.y-1) then
  begin
   sp.x:=0;
   sp.y:=0;
   l:=buf.dwSize.x*buf.dwSize.y;
   FillConsoleOutputCharacterA(GetStdHandle(STD_OUTPUT_HANDLE),' ',l,sp,ww);
   FillConsoleOutputAttribute(GetStdHandle(STD_OUTPUT_HANDLE),textAttr,l,sp,ww);
  end
  else begin
        l:=tw.Right-tw.Left+1;
        sp.x:=tw.Left;
        for i:=tw.Top to tw.Bottom do
         begin
          sp.y:=i;
          FillConsoleOutputCharacterA(GetStdHandle(STD_OUTPUT_HANDLE),' ',l,sp,ww);
          FillConsoleOutputAttribute(GetStdHandle(STD_OUTPUT_HANDLE),textAttr,l,sp,ww);
         end;
       end;
end;

procedure hide;
var
 r:TRect;
 w,h:integer;
 handle:HWND;
begin
 handle:=GetConsoleWindow;
 windows.GetWindowRect(handle,r);
 w:=r.right-r.left;
 h:=r.bottom-r.top;

 windows.SetWindowPos(GetConsoleWindow,HWND_BOTTOM,r.left,r.Top,w,h,SWP_NOACTIVATE);
end;

destructor TConsoleApplication.Destroy;
begin
 _self:=nil;
 FCommandLine.Free;
 windows.SetConsoleCtrlHandler(@consoleProcHandler,false);
 CloseHandle(FHandle);
 System.ExitCode:=self.ExitCode;
 inherited Destroy;
end;

function TConsoleApplication.getTitle: WideString;
var
 sz:DWORD;
 buf:PWideChar;
begin
 Result:='';
 sz:=0;
 if windows.GetConsoleTitleW(nil,sz)<>0 then
  begin
   buf:=AllocMem(sz*SizeOf(WideChar));
   if windows.GetConsoleTitleW(buf,sz)>0 then
    Result:=WideString(buf);
   FreeMem(buf,sz*SizeOf(WideChar)); 
  end;
end;

procedure TConsoleApplication.setPosition(aPosition: TConsoleWindowPosition);
var
 r:TRect;
 w,h:integer;
begin
 FHandle:=GetConsoleWindow;
 windows.GetWindowRect(FHandle,r);
 w:=r.right-r.left;
 h:=r.bottom-r.top;

 case aPosition of
  cwDefault:;
  cwLeft:;
  cwRight:;
  cwTop:;
  cwBottom:;
  cwDesktopCenter:windows.SetWindowPos(FHandle,0,(GetSystemMetrics(SM_CXFULLSCREEN)-w) div 2,(GetSystemMetrics(SM_CYFULLSCREEN)-h) div 2,0,0,SWP_NOSIZE);
  cwScreenCenter:;
 end;
end;

procedure TConsoleApplication.setTextPositionXY(X, Y: SmallInt);
var
 hStdOutput:ShortInt;
 p:TCoord;
begin
 hStdOutput:=GetStdHandle(STD_OUTPUT_HANDLE);
 p.x:=X;
 p.y:=Y;
 windows.SetConsoleCursorPosition(hStdOutput,p);
end;

procedure TConsoleApplication.setTitle(aTitle: WideString);
begin
 windows.SetConsoleTitleW(PWideChar(aTitle));
end;

procedure TConsoleApplication.SetBackgroundColor(aColor:Byte);
var
 hStdOutput:ShortInt;
 buf:TConsoleScreenBufferInfo;
 attr:Byte;
begin
 if Self.FHandle=0 then Exit;
 hStdOutput:=GetStdHandle(STD_OUTPUT_HANDLE);
 if not GetConsoleScreenBufferInfo(hStdOutput,buf) then Exit;
 attr:=buf.wAttributes and $FF;
 attr:=(attr and $0F) or ((aColor shl 4) and $F0);
 SetConsoleTextAttribute(hStdOutput,attr);
end;

procedure TConsoleApplication.SetTextColor(aColor: Byte);
var
 hStdOutput:ShortInt;
 buf:TConsoleScreenBufferInfo;
 attr:Byte;
begin
 if Self.FHandle=0 then Exit;
 hStdOutput:=GetStdHandle(STD_OUTPUT_HANDLE);
 if not GetConsoleScreenBufferInfo(hStdOutput,buf) then Exit;
 attr:=buf.wAttributes and $FF;
 attr:=(attr and $F0) or (aColor and $0F);
 SetConsoleTextAttribute(hStdOutput,attr);
end;

procedure TConsoleApplication.HighVideo;
var
 hStdOutput:ShortInt;
 buf:TConsoleScreenBufferInfo;
 attr:Byte;
begin
 if Self.FHandle=0 then Exit;
 hStdOutput:=GetStdHandle(STD_OUTPUT_HANDLE);
 if not GetConsoleScreenBufferInfo(hStdOutput,buf) then Exit;
 attr:=buf.wAttributes and $FF;
 attr:=(attr and $08);
 SetConsoleTextAttribute(hStdOutput,attr);
end;

procedure TConsoleApplication.LowVideo;
var
 hStdOutput:ShortInt;
 buf:TConsoleScreenBufferInfo;
 attr:Byte;
begin
 if Self.FHandle=0 then Exit;
 hStdOutput:=GetStdHandle(STD_OUTPUT_HANDLE);
 if not GetConsoleScreenBufferInfo(hStdOutput,buf) then Exit;
 attr:=buf.wAttributes and $FF;
 attr:=(attr and $F7);
 SetConsoleTextAttribute(hStdOutput,attr);
end;

procedure TConsoleApplication.NormalVideo;
var
 hStdOutput:ShortInt;
 buf:TConsoleScreenBufferInfo;
 attr:Byte;
begin
 if Self.FHandle=0 then Exit;
 hStdOutput:=GetStdHandle(STD_OUTPUT_HANDLE);
 if not GetConsoleScreenBufferInfo(hStdOutput,buf) then Exit;
 attr:=buf.wAttributes and $FF;
 SetConsoleTextAttribute(hStdOutput,attr);
end;

function _getConsoleDisplayMode(var lpdwMode:DWORD):boolean;
type TGetConsoleDisplayMode = function(var lpdwMode:DWORD):BOOL;stdcall;
var
 hKernel:THandle;
 f:TGetConsoleDisplayMode;
begin
 Result := False;
 hKernel:=GetModuleHandle('kernel32.dll');
 if hKernel>0 then
  begin
   @f:=GetProcAddress(hKernel,'GetConsoleDisplayMode');
   if Assigned(f) then Result:=f(lpdwMode);
  end;
end;

function _setConsoleDisplayMode(hOut:THandle;dwNewMode:DWORD;var lpdwOldMode:DWORD):boolean;
type TSetConsoleDisplayMode = function(hOut:THandle;dwNewMode:DWORD;var lpdwOldMode:DWORD):BOOL;stdcall;
var
 hKernel:THandle;
 f:TSetConsoleDisplayMode;
begin
 Result:=false;
 hKernel:=GetModuleHandle('kernel32.dll');
  if hKernel>0 then
   begin
    @f:=GetProcAddress(hKernel,'SetConsoleDisplayMode');
    if Assigned(f) then Result:=f(hOut,dwNewMode,lpdwOldMode);
  end;
end;

function TConsoleApplication.setFullScreen(aFullScreen:boolean):boolean;
const MAGIC_CONSOLE_TOGGLE = 57359;
var
 dwOldMode,dwNewMode:DWORD;
 hStdOutput:ShortInt;
 hConsole:HWND;
begin
 Result:=false;
 if Self.FHandle=0 then Exit;
 if Win32Platform = VER_PLATFORM_WIN32_NT then
  begin
   dwNewMode:=Ord(aFullScreen);
   _getConsoleDisplayMode(dwOldMode);
   hStdOutput:=GetStdHandle(STD_OUTPUT_HANDLE);
   Result:=_setConsoleDisplayMode(hStdOutput,dwNewMode,dwOldMode);
  end
 else
  begin
   hConsole:=GetConsoleWindow;
   Result:=hConsole<>0;
   if Result then
    begin
     if aFullScreen then SendMessage(GetConsoleWindow,WM_COMMAND,MAGIC_CONSOLE_TOGGLE,0)
      else
       begin
        keybd_event(VK_MENU,MapVirtualKey(VK_MENU,0),0,0);
        keybd_event(VK_RETURN,MapVirtualKey(VK_RETURN,0),0,0);
        keybd_event(VK_RETURN,MapVirtualKey(VK_RETURN,0),KEYEVENTF_KEYUP,0);
        keybd_event(VK_MENU,MapVirtualKey(VK_MENU,0),KEYEVENTF_KEYUP,0);
      end;
    end;
  end;
end;

procedure TConsoleApplication.textpos(x, y: SmallInt);
begin
 if Self.FHandle=0 then Exit;
 setTextPositionXY(x,y);
end;

function TConsoleApplication.disableInput:DWORD;
var m:DWORD;
begin
 Result:=0;
 if Self.FHandle=0 then Exit;
 windows.GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE),m);
 Result:=m;
 windows.SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE),m and not ENABLE_ECHO_INPUT);
end;

function TConsoleApplication.enableInput:DWORD;
var m:DWORD;
begin
 Result:=0;
 if Self.FHandle=0 then Exit;
 windows.GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE),m);
 Result:=m;
 windows.SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE),m and not ENABLE_ECHO_INPUT);
end;

procedure TConsoleApplication.showCursor(aShow: boolean);
var info:TConsoleCursorInfo;
begin
 if Self.FHandle=0 then Exit;
 info.bVisible:=aShow;
 info.dwSize:=1;
 windows.SetConsoleCursorInfo(GetStdHandle(STD_OUTPUT_HANDLE),info);
end;

function TConsoleApplication.IntOnCloseQuery(const aType: DWORD): boolean;
begin
 IntOnDestroy(Self);
 Result:=True;
end;

function TConsoleApplication.IntOnTerminate(const aType: DWORD): boolean;
begin
 IntTerminateProcess(Self);
 Result:=True;
end;

procedure TConsoleApplication.IntOnDestroy(Sender: TObject);
begin
 if Assigned(FOnDestroy) then FOnDestroy(Sender);
end;

procedure TConsoleApplication.IntTerminateProcess(Sender: TObject);
begin
 if Assigned(FOnTerminate) then FOnTerminate(Sender);
end;

procedure TConsoleApplication.InitDefaultConsole;
begin
 showCursor(false);
 SetBackgroundColor(Blue);
 SetTextColor(LightGray);
 clearText;
 textpos(1,1);
 showCursor(false);
end;

procedure TConsoleApplication.processMessages;
var msg:TMsg;
begin
  while ProcessMessage(msg) do {loop};
end;

function TConsoleApplication.processMessage(var msg: TMsg):boolean;
begin
 Result:=False;
 if PeekMessage(msg,0,0,0,PM_REMOVE) then
  begin
   Result:=True;
   if msg.message=WM_QUIT then IntTerminateProcess(Self)
    else
     begin
      TranslateMessage(msg);
      DispatchMessage(msg);
     end;
  end;   
end;

function TConsoleApplication.output(v:WideString):TConsoleApplication;
begin
 Result:=Self;
 if Self.FHandle=0 then Exit;
 write(string(v));
end;

function TConsoleApplication.anykey:TConsoleApplication;
begin
 Result:=Self;
 if Self.FHandle=0 then Exit;
 readln;
end;

function TConsoleApplication.newline:TConsoleApplication;
begin
 Result:=Self;
 if Self.FHandle=0 then Exit;
 writeln;
end;

end.
