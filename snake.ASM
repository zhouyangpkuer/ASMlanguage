DRAW MACRO START_X, START_Y, END_X, END_Y, COLOR  ;宏定义显示图形界面
        LOCAL DRAW_NEXT
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        MOV AH, 0CH                 ;写像素点
        MOV AL, COLOR               ;设置颜色
        MOV BH, 0                   ;选用页号3
        MOV CX, START_X             ;列起始点
        MOV DX, START_Y             ;行起始点

DRAW_NEXT:
        INT 10H                     ;画点
        INC CX                      ;画横线
        CMP CX, END_X               ;比较行是否画完
        JNE DRAW_NEXT               ;画另一行
        MOV CX, START_X             ;另一行的起始点
        INC DX
        CMP DX, END_Y               ;比较列是否画完
        JNE DRAW_NEXT               ;未完继续画
        POP DX
        POP CX
        POP BX
        POP AX
ENDM

DRAW_BLOCK MACRO START_X, START_Y, COLOR  ;宏定义显示图形界面
        PUSH BX
        MOV BX, START_X
        MOV SX, BX
        ADD SX, 1
        MOV EX, BX
        ADD EX, 14       
        
        MOV BX, START_Y
        MOV SY, BX
        ADD SY, 1
        MOV EY, BX
        ADD EY, 14
        ;DRAW START_X + 1, START_Y + 1, START_X + 14, START_Y + 14, COLOR
        DRAW SX, SY, EX, EY, COLOR
        POP BX
ENDM

;宏定义
FORWARD MACRO A             ;将数组A以word为单位前移，表示蛇的前进
        LOCAL LL
        MOV BX,OFFSET A
        MOV CH,0
        MOV CL,LEN
        DEC CX
        ADD CX,CX
LL: 
        MOV DL,[BX+2]
        MOV [BX],DL
        INC BX
        LOOP LL
ENDM

SET_LED1 MACRO X,Y          ;设坐标(x,y)的二极管亮起（限上半部，用于初始化）
        MOV BX,OFFSET LED1
        MOV CL,X
        MOV DL,80H
        SHR DL,CL
        OR  [BX+Y],DL
ENDM


DATA SEGMENT
        GO1   DB 01111100B, 10000010B, 10001010B, 10001111B, 01111111B, 10010000B, 10010000B, 01111111B
              DB 11111111B, 00011111B, 00011111B, 11111111B, 11111111B, 10010001B, 10010001B, 10010001B
        GO2   DB 01111110B, 10000001B, 10000001B, 01111110B, 11111110B, 00000001B, 00000001B, 11111110B
              DB 11111111B, 10010001B, 10010001B, 10010001B, 11111111B, 10011000B, 10010100B, 11110011B

        INDEX_GO DB  00h
        LOOPTIMER DB 00h

        DIR     DB 0                ;当前行进方向，左1右2上3下4
        FOODX   DB 0                ;食物坐标
        FOODY   DB 0
        LEN     DB 0                ;当前蛇长
        LEVEL   DB 0                ;当前难度等级（1-3，共三级）
        LV_     DW 0                ;根据等级而定的控制参数
        SCORE   DW 0                ;得分，个、十、百位
        SC1     DB 0
        SC2     DB 0
        SC3     DB 0
        HEADX   DB 0                ;蛇头坐标
        HEADY   DB 0
        TAILX   DB 0                ;蛇尾坐标
        TAILY   DB 0
        SNAKE   DB 512 DUP(0)       ;蛇每一节的坐标,最大节数256（头在后，尾在前）
        FLAG    DB 0                ;GAME OVER的标志
        EATFOOD DB 0                ;蛇是否吃了food，决定它是否消除tail

        OVER    DB 'GAME OVER!',0dh,0ah,'$'
        PAUSE   DB 'pause...press Space to continue',0dh,0ah,'$'
        LV_MESS DB 'Please choose the level : '
        LEN_LV    EQU     $ - LV_MESS

        SC_MESS DB 'Your score is : ','$'

        MSG1    DB 'Welcome to MyGreedySnake!',0dh, 0ah
        LEN1    EQU     $ - MSG1

        MSG2    DB 'Press : ',0dh,0ah
        LEN2    EQU     $ - MSG2

        MSG3    DB 'Direction key to control',0dh,0ah
        LEN3    EQU     $ - MSG3

        MSG4    DB 'Space to pause or continue',0dh,0ah
        LEN4    EQU     $ - MSG4

        MSG5    DB 'ESC to exit',0dh,0ah
        LEN5    EQU     $ - MSG5

        MSG6    DB 'Sorce : ',0dh,0ah
        LEN6    EQU     $ - MSG6

        MSG7    DB 'Designed by ZhouYang@pku.',0dh,0ah
        LEN7    EQU     $ - MSG7

        NUMLED  DB 3FH,06H,5BH,4FH,66H,6DH,7DH,07H 
                DB 7FH,67H,77H,7CH,39H,5EH,79H,71H;数码管换码
        
        LED1    DB 16 DUP(0)        ;点阵上半部
        LED2    DB 16 DUP(0)        ;点阵下半部
        
        LED3    DB 16 DUP(0)        ;记录上次的点阵上半部
        LED4    DB 16 DUP(0)        ;记录上次的点阵下半部

        LEDX    DB 0                ;需要控制的二极管阵列坐标，用于传递参数
        LEDY    DB 0
        INDEX   DB 0                ;二极管阵列的列索引，用于控制显示
        
        SX      DW 0
        SY      DW 0
        EX      DW 0
        EY      DW 0
        
        TEMP1   DW 0
        TEMP2   DW 0
        TEMP_COLOR  DB 0

        IRQ6    DB 0                ;是否进入中断的标志

DATA ENDS

STACK SEGMENT PARA STACK
        DW 100 DUP(0)
STACK ENDS

CODE SEGMENT
ASSUME CS:CODE, SS:STACK, ES:DATA, DS:DATA

;主程序
START:

        MOV AX,DATA      ;段寄存器初始化
        MOV DS,AX
        MOV ES,AX
        MOV AX,STACK
        MOV SS,AX

        MOV AH,0            ;设置屏幕显示方式
        MOV AL,12H          ;EGA 640×480 16色
        INT 10H
        
        MOV AH,0BH          ;置彩色调板
        MOV BH,0H
        MOV BL,10H           ;背景色为黑色
        INT 10H

        MOV BP, OFFSET LV_MESS
        MOV CX, LEN_LV
        MOV DH, 10             ;行
        MOV DL, 27             ;列
        MOV BH, 0              ;设置页号
        MOV BL, 01101111B      ;棕底白字
        MOV AL, 1
        MOV AH, 13H
        INT 10H

        DRAW 160, 180, 480, 185, 0EH

        MOV BH,0            
        MOV DH,12           ;行
        MOV DL,39           ;列
        MOV AH,2            ;置光标位置
        INT 10H

        MOV AH,02H                
        MOV DL,1
        ADD DL,30H
        INT 21H

        MOV BH,0            
        MOV DH,13           ;行
        MOV DL,39           ;列
        MOV AH,2            ;置光标位置
        INT 10H

        MOV AH,02H                 
        MOV DL,2
        ADD DL,30H
        INT 21H

        MOV BH,0            
        MOV DH,14           ;行
        MOV DL,39           ;列
        MOV AH,2            ;置光标位置
        INT 10H
        
        MOV AH,02H                 
        MOV DL,3
        ADD DL,30H
        INT 21H

        MOV CL, 1
        DRAW 240, 195, 310, 205, 0AH
        DRAW 320, 195, 400, 205, 0AH
       ; STI
KKK:
        MOV AL, 0H
        MOV AH, 0BH
        INT 21H
        CMP AL, 0FFH
        JNE KKK
       ; MOV AH, 01H
       ; MOV DL, 0FFH
       ; INT 16H
       ; JZ KKK

        MOV AL,00H
        MOV AH, 07H              
        INT 21H

        CMP AL, 48H			;上箭头
        JZ UP

        CMP AL, 50H			;下箭头
        JZ DOWN

        CMP AL, 0DH			;enter键
        JZ _ENTER

        JMP KKK 			;其他键
UP:
        CALL UP_F
        CMP CL, 1
        JZ UP1
        CMP CL, 2
        JZ UP2
        CMP CL, 3
        JZ UP3
UP3:
        CALL UP3_F
        JMP KKK
UP2:
        CALL UP2_F
        JMP KKK
UP1:
        CALL UP1_F
        JMP KKK
DOWN:	
        CALL DOWN_F
        CMP CL, 3
        JZ DOWN3
        CMP CL, 2
        JZ DOWN2
        CMP CL, 1
        JZ DOWN1
DOWN3:
        CALL DOWN3_F
        JMP KKK
DOWN2:
        CALL DOWN2_F
        JMP KKK
DOWN1:
        CALL DOWN1_F
        JMP KKK
_ENTER:
        MOV LEVEL, CL 

        MOV AL,36H             ;设置8253，通道0，方式3
        MOV DX,0E483H
        OUT DX,AL
        MOV DX,0E480H
        MOV AX,10000            ;计数初值5000，频率为200Hz
        OUT DX,AL
        MOV AL,AH
        OUT DX,AL
                               ;设置中断向量
        MOV AX, CS
        MOV DS, AX             ;DS:IRQ SEGMENT ADDRESS
        MOV DX, OFFSET IRQ     ;DX:IRQ OFFSET
        MOV AX, 250EH          ;AH = 25H
        INT 21H
        CLI
        MOV DX, 0EC4CH         ;PCI9052(LOW)
        MOV AL, 43H
        OUT DX, AL
        INC DX                 ;PCI9052(HIGH)
        MOV AL, 1DH            ;CLEAN FLAG
        OUT DX, AL
        IN AL, 21H             ;SET 8259A OCW1
        AND AL, 10111111B      ;D6 = 0
        OUT 21H, AL
        MOV AX, DATA           ;恢复DS段寄存器 
        MOV DS, AX
        STI

        MOV DX,0E48BH          ;设置 8255A
        MOV AL,81H             ;A,B OUT: 数码管; PC0-3 IN, PC4-7 OUT;
        OUT DX,AL 

        MOV SI,0               ;COUNTER
        MOV DI,1               ;S0 OR S1 OR S2
        MOV SC1,0
        MOV SC2,0
        MOV SC3,0

        MOV DX,0E4ABH          ;设置控制二极管阵列的 8255A
        MOV AL,80H
        OUT DX,AL

        

;完成对LV_依据level的赋值，进入游戏程序
SET_LV_:
        CMP LEVEL,3
        JNE LV2
        MOV LV_,1000               ;level 3
       ; MOV LV_,500
        JMP LV_EXIT
LV2:    CMP LEVEL,2
        JNE LV1
        MOV LV_,1500               ;level 2
       ; MOV LV_,500
        JMP LV_EXIT
LV1:    MOV LV_,2000               ;默认level 1
       ; MOV LV_,750

LV_EXIT:
        CALL INIT                  ;初始化绘图
        MOV DH,0
        MOV DL,0
        MOV BH,0
        MOV AH,2
        INT 10H                    ;置光标位置


        MOV INDEX, 0H
        MOV DIR,2                  ;初始方向向右

        CALL INIT_SNAKE            ;初始化蛇的参数
        CALL RAND_LOC              ;得到随机的食物坐标


;程序主体循环，表示蛇的行进
S_MOVE:
        MOV IRQ6,0
L_IRQ:                             ;等待中断，期间调用DISPLAY过程
        CALL DISPLAY
        CMP IRQ6,1
        JNE L_IRQ
LED_SETFOOD:
        MOV DH,FOODX               ;设置食物对应的二极管亮起
        MOV DL,FOODY
        MOV LEDX,DH
        MOV LEDY,DL
        CALL LED_SET1

        MOV AH,86H
        MOV CX,0
        MOV DX,500H
        INT 15H

        CMP EATFOOD, 1H
        JZ GETFOOD                 ;上次吃到了food 
        
        CALL HIDE_SNAKE_TAIL       ;清除蛇尾
GETFOOD:
        MOV EATFOOD, 0H            ;标记清零
        CALL SHOW_SNAKE_HEAD       ;显示蛇头
        CMP FLAG,1                 ;是否触发结束条件
        JZ L_EXIT

        MOV AL,0                   ;检验键盘状态，AL=0 有输入，AL=FF 无输入
        MOV AH,0BH
        INT 21H 
        CMP AL,0FFH
        JZ S_NEXT
        JMP S_MOVE
J_S_MOVE:                          ;接力跳转
        JMP S_MOVE 

S_NEXT: 
        MOV AL,0                   ;读取按键
        MOV AH,7
        INT 21H

        CMP AL,4BH                 ;左箭头
        JZ S_LEFT

        CMP AL,4DH                 ;右箭头
        JZ S_RIGHT

        CMP AL,48H                 ;上箭头
        JZ S_UP

        CMP AL,50H                 ;下箭头
        JZ S_DOWN

        CMP AL,20H                 ;空格
        JZ S_PAUSE

        CMP AL,1BH                 ;ESC
        JZ GAME_OVER
        JMP J_S_MOVE               ;其它
L_EXIT:                            ;接力跳转
        JMP GAME_OVER

S_LEFT:
        CMP DIR,2                  ;原来是向右吗？
        JZ  J_S_MOVE               ;不允许反向，继续行进
        MOV DIR,1                  ;方向改为向左
        JMP J_S_MOVE
S_RIGHT:
        CMP DIR,1                  ;原来是向左吗？
        JZ  J_S_MOVE
        MOV DIR,2                  ;方向改为向右
        JMP J_S_MOVE
S_UP:
        CMP DIR,4                  ;原来是向下吗？
        JZ  J_S_MOVE
        MOV DIR,3                  ;方向改为向上
        JMP J_S_MOVE
S_DOWN:
        CMP DIR,3                  ;原来是向上吗？
        JZ  J_S_MOVE
        MOV DIR,4                  ;方向改为向下
        JMP J_S_MOVE
S_PAUSE:
       ; MOV AH,9                   ;显示暂停信息
       ; MOV DX,OFFSET PAUSE
       ; INT 21H
L_PAUSE:
        MOV AH,0BH                 ;读取键盘状态
        MOV AL,0
        INT 21H
        CMP AL,0FFH
        JZ P_NEXT
        CALL DISPLAY               ;无输入，显示得分和二极管阵列游戏界面
        JMP L_PAUSE
P_NEXT:
        MOV AH,7
        INT 21H
        CMP AL,20H                 ;空格键，继续游戏
        JNE L_PAUSE
        JMP J_S_MOVE

GAME_OVER:                         ;游戏结束
        IN AL,21H
        OR AL,40H                  ;关闭IRQ6中断
        OUT 21H,AL
        MOV DX,0EC4CH
        MOV AL,42H
        OUT DX,AL                  ;关闭PCI 9052中断
        STI

        CALL BEEP                  ;调用BEEP鸣响

        ;显示结束弹幕
        MOV DX,0E4ABH
    	MOV AL,80h
     	OUT DX,AL
     	MOV BX,0H
S0:  
     	MOV DX,0E4A8H				;a
     	MOV AL,INDEX_GO
     	PUSH BX
        MOV BX, OFFSET GO2
     	XLAT
     	POP BX
     	OUT DX,AL

     	MOV DX,0E4A9H				;b
     	MOV AL,INDEX_GO
     	PUSH BX
        MOV BX, OFFSET GO1
     	XLAT
     	POP BX
     	OUT DX,AL

        INC INDEX_GO
    	CMP INDEX_GO, 010H
    	JNZ _GOON
    	SUB INDEX_GO, 010H

_GOON:
    	MOV DX,0E4AAH		       ;c
     	MOV AL,BL
     	OUT DX,AL

	MOV AH,86H
	MOV CX,0
	MOV DX,90H
	INT 15H
		
        ADD BL,1H
	CMP BL,010H
	JNZ KEY0
	MOV BL,0
	INC LOOPTIMER
	CMP LOOPTIMER,04FH
	JNZ KEY0
	SUB LOOPTIMER,04FH
	INC INDEX_GO
	CMP INDEX_GO, 010H
	JNZ KEY0
	SUB INDEX_GO, 010H
KEY0:
   	MOV AH,1
    	INT 16H
    	JZ  S0

    	DRAW 0, 0, 639, 479, 0H
    	MOV AH,4CH
    	INT 21H

UP_F PROC
        DRAW 240, 195, 310, 205, 00H
        DRAW 320, 195, 400, 205, 00H
       	
        DRAW 240, 210, 310, 220, 00H
        DRAW 320, 210, 400, 220, 00H
       	
        DRAW 240, 225, 310, 235, 00H
        DRAW 320, 225, 400, 235, 00H
        RET
UP_F ENDP 
UP1_F PROC
        DRAW 240, 195, 310, 205, 0AH
        DRAW 320, 195, 400, 205, 0AH
        RET
UP1_F ENDP

UP2_F PROC
        DRAW 240, 195, 310, 205, 0AH
        DRAW 320, 195, 400, 205, 0AH
        DEC CL
        RET
UP2_F ENDP

UP3_F PROC
        DRAW 240, 210, 310, 220, 0AH
        DRAW 320, 210, 400, 220, 0AH
        DEC CL
        RET
UP3_F ENDP

DOWN_F PROC
        DRAW 240, 195, 310, 205, 00H
        DRAW 320, 195, 400, 205, 00H
      
        DRAW 240, 210, 310, 220, 00H
        DRAW 320, 210, 400, 220, 00H

        DRAW 240, 225, 310, 235, 00H
        DRAW 320, 225, 400, 235, 00H
        RET
DOWN_F ENDP

DOWN1_F PROC
        DRAW 240, 210, 310, 220, 0AH
        DRAW 320, 210, 400, 220, 0AH
       	INC CL
       	RET
DOWN1_F ENDP

DOWN2_F PROC
        DRAW 240, 225, 310, 235, 0AH
        DRAW 320, 225, 400, 235, 0AH
        INC CL
        RET
DOWN2_F ENDP

DOWN3_F PROC
       	DRAW 240, 225, 310, 235, 0AH
       	DRAW 320, 225, 400, 235, 0AH
        RET
DOWN3_F ENDP

;子过程
RAND_LOC PROC                      ;得到随机横、纵坐标
        PUSH AX
        PUSH BX
        PUSH DX
RE_RAND:
        CALL SRAND                 ;CH:CL = 时:分  DH:DL = 秒:1/100秒
        MOV AX,DX
        AND AH,00001111B
        MOV DL,16
        DIV DL                     ;取余数作为随机坐标
        MOV FOODX,AH

        CALL SRAND
        MOV AX,DX
        AND AH,00001111B
        MOV DL,16
        DIV DL
        MOV FOODY,AH

        MOV LEDY,AH
        MOV AH,FOODX
        MOV LEDX,AH 
        CALL CHECK_LED             ;检查得到的随机坐标是否合法（不在蛇身上）
        JNE RE_RAND                ;不合法则重新求随机坐标

        POP DX
        POP BX
        POP AX
        RET
RAND_LOC ENDP

SRAND PROC                         ;根据系统时间得到随机数，返回DX
        PUSH AX
        PUSH CX
        STI
        MOV AH,0
        INT 1AH                    ;读系统时间，DH:DL = 秒:1/100秒

        POP CX
        POP AX
        RET
SRAND ENDP

HIDE_SNAKE_TAIL PROC               ;清除贪食蛇尾
        PUSH BX
        PUSH CX
        PUSH DX
SET0:
        MOV DH,TAILX
        MOV DL,TAILY
        MOV LEDX,DH
        MOV LEDY,DL
        CALL LED_SET0              ;设置蛇尾对应的二极管熄灭

        FORWARD SNAKE              ;把贪食蛇前移一个word

        MOV BX,OFFSET SNAKE
        MOV DH,[BX]
        MOV DL,[BX+1]
        MOV TAILX,DH               ;NEW TAIL
        MOV TAILY,DL

        POP DX
        POP CX
        POP BX
        RET
HIDE_SNAKE_TAIL ENDP

SHOW_SNAKE_HEAD PROC               ;显示贪食蛇头
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX

        MOV AH,0
        MOV AL,LEN
        ADD AX,AX                  ;2 * len
        SUB AX,4
        MOV BX,OFFSET SNAKE
        ADD BX,AX                  ;HEAD

        MOV AH,HEADX
        MOV AL,HEADY
JUDGE:
        CMP DIR,1                  ;贪食蛇头方向往左
        JZ S_TO_LEFT
        CMP DIR,2                  ;贪食蛇头方向往右
        JZ S_TO_RIGHT
        CMP DIR,3                  ;贪食蛇头方向往上
        JZ S_TO_UP
        CMP DIR,4                  ;贪食蛇头方向往下
        JZ S_TO_DOWN
S_TO_LEFT:
        DEC AL
        JMP S_TO_NEXT
S_TO_RIGHT:
        INC AL
        JMP S_TO_NEXT
S_TO_UP:
        DEC AH
        JMP S_TO_NEXT
S_TO_DOWN:
        INC AH
        JMP S_TO_NEXT

S_TO_NEXT:
        MOV [BX+2],AH               ;NEW HEAD
        MOV [BX+3],AL
        MOV HEADX,AH
        MOV HEADY,AL

        CMP AH,-1                   ;横坐标越界？
        JZ S_ERROR
        CMP AH,16
        JZ S_ERROR

        CMP AL,-1                   ;纵坐标越界？
        JZ S_ERROR
        CMP AL,16
        JZ S_ERROR

        CALL BITESELF               ;检查蛇是否咬到自身
        CMP FLAG,1
        JZ S_EXIT

        MOV CH,FOODX
        MOV CL,FOODY

        CMP AH,CH                   ;食物与蛇头行号是否相等
        JNZ S_TO_LAST
        CMP AL,CL                   ;列号是否相等
        JNZ S_TO_LAST

        MOV EATFOOD, 1H             ;设置吃到食物标记
        CALL RAND_LOC               ;吃到食物，重新得到随机坐标

        CALL BEEP                   ;响一声

        INC LEN                     ;增加蛇长和得分
        INC SCORE
        INC SC1
        CMP SC1,10
        JNE SC_NEXT
        MOV SC1,0
        INC SC2
        CMP SC2,10
        JNE SC_NEXT
        MOV SC2,0
        INC SC3
        CMP SC3,10
        JNE SC_NEXT
        MOV SC3,0
        JMP SC_NEXT
SC_NEXT:
        JMP S_TO_LAST

S_ERROR:                            ;设置结束标记
        MOV FLAG,1
        JMP S_EXIT

S_TO_LAST:
        MOV DH,AH                   ;设置新蛇头对应的二极管亮起
        MOV DL,AL
        MOV LEDX,DH
        MOV LEDY,DL
        CALL LED_SET1
S_EXIT:
        POP DX
        POP CX
        POP BX
        POP AX
        RET
SHOW_SNAKE_HEAD ENDP

BITESELF PROC                       ;检查是否咬到蛇身，参数: AH,AL - 蛇头坐标
        PUSH AX
        PUSH BX
        PUSH CX

        MOV CH,0
        MOV CL,LEN
        SUB CL,3                    ;蛇头不可能咬到前4节
        MOV BX,OFFSET SNAKE
S_BITE:                             ;循环检查每一节
        JCXZ BITE_EXIT
        CMP AH,[BX]
        JNZ BITE_NEXT
        CMP AL,[BX+1]
        JNZ BITE_NEXT

        MOV FLAG,1                  ;设置结束标志
        JMP BITE_EXIT
BITE_NEXT:
        ADD BX,2
        DEC CL
        JMP S_BITE
BITE_EXIT:
        POP CX
        POP BX
        POP AX
        RET
BITESELF ENDP

INIT_SNAKE PROC                     ;设置贪食蛇初始参数
        PUSH BX
        PUSH CX
        PUSH DX

        SET_LED1 1,1                ;二极管阵列(1,1),(1,2),(1,3)亮起
        SET_LED1 1,2
        SET_LED1 1,3

        MOV DH,1
        MOV DL,1
        MOV BX,OFFSET SNAKE
        MOV CX,3                    ;蛇身初始3节
S10:
        MOV [BX],DH                 ;初始贪食蛇蛇身坐标
        MOV [BX+1],DL
        ADD BX,2                    ;下一节
        INC DL
        LOOP S10

        MOV LEN,3
        MOV DIR,2                   ;初始方向向右

        MOV HEADX,1
        MOV HEADY,3                 ;初始蛇头(1,3)

        MOV TAILX,1
        MOV TAILY,1                 ;初始蛇尾(1,1)

        POP DX
        POP CX
        POP BX
        RET
INIT_SNAKE ENDP

LED_SET1 PROC                       ;设置二极管阵列坐标(LEDX,LEDY)亮起
        PUSH BX
        PUSH DX
        MOV DH,LEDX
        MOV DL,LEDY
        MOV CL,DH
        CMP CL,7                    ;是否上半部
        JLE LS1
        MOV BX,OFFSET LED2          ;下半部
        SUB CL,8
        JMP LS1_
LS1:    MOV BX,OFFSET LED1
LS1_:   MOV DH,0
        ADD BX,DX
        MOV DL,80H
        SHR DL,CL
        OR  [BX],DL

        POP DX
        POP BX
        RET
LED_SET1 ENDP

LED_SET0 PROC                       ;设置二极管阵列坐标(LEDX,LEDY)熄灭
        PUSH BX
        PUSH DX

        MOV DH,LEDX
        MOV DL,LEDY
        MOV CL,DH
        CMP CL,7                    ;是否上半部
        JLE LS0
        MOV BX,OFFSET LED2          ;下半部
        SUB CL,8
        JMP LS0_
LS0:    MOV BX,OFFSET LED1
LS0_:   MOV DH,0
        ADD BX,DX
        MOV DL,80H
        SHR DL,CL
        NOT DL
        AND [BX],DL
        POP DX
        POP BX
        RET
LED_SET0 ENDP

CHECK_LED PROC                     ;检查二极管阵列(LEDX,LEDY)是否亮起，返回ZF
        PUSH BX
        PUSH DX

        MOV DH,LEDX
        MOV DL,LEDY
        MOV CL,DH
        CMP CL,7
        JLE CL1
        MOV BX,OFFSET LED2         ;下半部
        SUB CL,8
        JMP CL2
CL1:    MOV BX,OFFSET LED1         ;上半部
CL2:    MOV DH,0
        ADD BX,DX
        MOV DL,80H
        SHR DL,CL
        MOV AL,[BX]
        AND AL,DL

        POP DX
        POP BX
        RET
CHECK_LED ENDP

DISPLAY PROC                       ;数码管和二极管阵列的显示子过程
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX

LOOP1:
        INC SI                     ;循环计数
;数码管
        MOV AX,DI
        MOV DX,0E488H
        OUT DX,AL                  ;A OUT(位码)

        SHL DI,1                   ;选择数码管的当前显示位
        
        CMP DI,2
        JZ  SS0
        CMP DI,4
        JZ  SS1
        MOV DI,1
        JMP SS2
SS0:
        MOV AH,0
        MOV AL,SC1
        JMP L01
SS1:
        MOV AH,0
        MOV AL,SC2
        JMP L01
SS2:
        MOV AH,0
        MOV AL,SC3
L01:
        AND AL,0FH
        MOV BX,OFFSET NUMLED
        XLAT                       ;换码

        ;MOV DX,0E48AH
        MOV DX,0E489H
        OUT DX,AL                  ;B OUT(段码)

;二极管阵列
SHOW:
        MOV DX,0E4A8H              ;A
        MOV AL,INDEX

        MOV BX, OFFSET LED2        ;下半部
        XLAT

        OUT DX,AL

        MOV DX,0E4A9H              ;B
        MOV AL,INDEX

        MOV BX, OFFSET LED1        ;上半部
        XLAT

        OUT DX,AL
GOON:                   
        MOV DX,0E4AAH              ;C
        MOV AL,INDEX               ;列索引
        OUT DX,AL
        INC INDEX
        CMP INDEX, 010H
        JNZ WAIT1
        SUB INDEX, 010H
WAIT1:
        MOV AH,86H
        MOV CX,0
        MOV DX,50H
        INT 15H
        
        CMP SI,LV_                  ;根据难度控制循环
        JNE NEAR PTR LOOP1
        MOV SI, 0

        ;将上次画的图像清为黑色
        CALL CLEAR_DRAW
        
        ;将这次的LED1.2存入LED3.4
        CALL COPY_LED
        
        ;绘制现在的图像
        CALL CURRENT_DRAW
        

        ;显示分数
        MOV BH,0            ;不显示会不会和这个有关？
        MOV DH,17           ;行
        MOV DL,21           ;列
        MOV AH,2            ;置光标位置
        INT 10H

        MOV AH,02H                 ;得分的百、十、个位
        MOV DL,SC3
        ADD DL,30H
        INT 21H
        MOV DL,SC2
        ADD DL,30H
        INT 21H
        MOV DL,SC1
        ADD DL,30H
        INT 21H
        
        MOV SI,0
        
        POP DX
        POP CX
        POP BX
        POP AX
        RET
DISPLAY ENDP

CURRENT_DRAW PROC
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        ;CL是LED屏的列
        MOV CL, 0
        MOV CH, 0
LOOOP1:
        ;AH是LED屏的行
        MOV AH, 0
LOOOP2:
        MOV DL,80H
        PUSH CX
        MOV CL, AH
        SHR DL, CL
        POP CX

        MOV BX,OFFSET LED1
        ADD BX,CX

        MOV DH, [BX] 
        AND DH, DL
        JZ SKIP1

        MOV TEMP_COLOR, 0CH
        CALL QUICK_DRAW_UP
SKIP1:

        MOV BX,OFFSET LED2
        ADD BX,CX

        MOV DH, [BX] 
        AND DH, DL
        JZ SKIP2

        MOV TEMP_COLOR, 0CH
        CALL QUICK_DRAW_DOWN
SKIP2:

        INC AH
        CMP AH, 8
        JNZ LOOOP2

        INC CL
        CMP CL, 16
        JNZ LOOOP1

      ;  MOV AH,9                   ;显示暂停信息
      ;  MOV DX,OFFSET C
      ;  INT 21H

        POP DX
        POP CX
        POP BX
        POP AX

        RET
CURRENT_DRAW ENDP

COPY_LED PROC
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX

        MOV CX, 0
LLOOP1:
        MOV BX, OFFSET LED1
        ADD BX, CX
        MOV DL, [BX]
        MOV BX, OFFSET LED3
        ADD BX, CX
        MOV [BX], DL
 
        MOV BX, OFFSET LED2
        ADD BX, CX
        MOV DL, [BX]
        MOV BX, OFFSET LED4
        ADD BX, CX
        MOV [BX], DL

        INC CX
        CMP CX, 16
        JNZ LLOOP1

      ;  MOV AH,9                   ;显示暂停信息
      ;  MOV DX,OFFSET B
      ;  INT 21H

        POP DX
        POP CX
        POP BX
        POP AX

        RET
COPY_LED ENDP

;CL(列）, AH（行）, TEMP_COLOR（颜色）
QUICK_DRAW_UP PROC
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        MOV BH, CL
        SHL CL, 1
        SHL CL, 1
        SHL CL, 1
        SHL CL, 1
        SUB CL, BH

        MOV DH, 0
        MOV DL, CL
        ADD DX, 360
        MOV TEMP1, DX

        MOV BH, AH
        SHL AH, 1
        SHL AH, 1
        SHL AH, 1
        SHL AH, 1
        SUB AH, BH

        MOV DH, 0
        MOV DL, AH
        ADD DX, 120
        MOV TEMP2, DX

        DRAW_BLOCK TEMP1, TEMP2, TEMP_COLOR

        POP DX
        POP CX
        POP BX
        POP AX
        RET
QUICK_DRAW_UP ENDP

;CL, AH, TEMP_COLOR
QUICK_DRAW_DOWN PROC
        
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        MOV BH, CL
        SHL CL, 1
        SHL CL, 1
        SHL CL, 1
        SHL CL, 1
        SUB CL, BH

        MOV DH, 0
        MOV DL, CL
        ADD DX, 360
        MOV TEMP1, DX

        MOV BH, AH
        SHL AH, 1
        SHL AH, 1
        SHL AH, 1
        SHL AH, 1
        SUB AH, BH

        MOV DH, 0
        MOV DL, AH
        ADD DX, 240
        MOV TEMP2, DX

        DRAW_BLOCK TEMP1, TEMP2, TEMP_COLOR

        POP DX
        POP CX
        POP BX
        POP AX
        RET
QUICK_DRAW_DOWN ENDP


CLEAR_DRAW PROC
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH DX
        ;CL是LED屏的列
        MOV CL, 0
        MOV CH, 0
LLLOOP1:
        ;AH是LED屏的行
        MOV AH, 0
LLLOOP2:
        MOV DL,80H
        PUSH CX
        MOV CL, AH
        SHR DL,CL
        POP CX

        MOV BX,OFFSET LED3
        ADD BX,CX

       ; AND [BX], DL;若不为零，则说明这个点需要被清零
        MOV DH, [BX] 
        AND DH, DL

        JZ SSKIP1

        MOV TEMP_COLOR, 00H
        CALL QUICK_DRAW_UP
SSKIP1:

        MOV BX,OFFSET LED4
        ADD BX,CX

       ; AND [BX], DL;若不为零，则说明这个点需要被清零
        MOV DH, [BX] 
        AND DH, DL

        JZ SSKIP2

        MOV TEMP_COLOR, 00H
        CALL QUICK_DRAW_DOWN
SSKIP2:

        INC AH
        CMP AH, 8
        JNZ LLLOOP2

        INC CL
        CMP CL, 16
        JNZ LLLOOP1

       ; MOV AH,9                   ;显示暂停信息
       ; MOV DX,OFFSET A
       ; INT 21H
        
        POP DX
        POP CX
        POP BX
        POP AX
        RET
CLEAR_DRAW ENDP

BEEP PROC NEAR                      ;扬声器发声子程序(BX控制发声时间)
        PUSH CX
        MOV BX,01FFH                ;控制时长
        MOV AL,10110110B            ;微机8253计数器2方式3,16位二进制计数
        OUT 43H,AL
        MOV AX,1190                 ;计数初值1190，频率1KHz
        OUT 42H,AL
        MOV AL,AH
        OUT 42H,AL
        IN AL,61H
        MOV AH,AL
        OR AL,03H
        OUT 61H,AL                  ;打开GATE2,使OUT2输出至扬声器
        MOV CX,0
        L0: LOOP L0
        DEC BX
        JNZ L0
        MOV AL,AH                   ;恢复微机8255A的PB口原值，停止发声
        OUT 61H,AL
        POP CX
        RET
BEEP ENDP

IRQ PROC FAR                        ;中断服务程序
        PUSH AX
        PUSH DX

        MOV AX,DATA
        MOV DS,AX
        MOV IRQ6,1                  ;设置进入中断的标志
        MOV AL,20H                  ;普通方式结束中断
        OUT 20H,AL
        MOV DX,0EC4DH
        MOV AL,1DH
        OUT DX,AL                   ;清除PCI 9052 的中断标志

        POP DX
        POP AX
        IRET
IRQ ENDP

INIT PROC NEAR
        MOV AX,DATA
        MOV DS,AX
        MOV ES, AX

        MOV AH,0            ;设置屏幕显示方式
        MOV AL,12H          ;EGA 640×480 16色
        INT 10H
        
        MOV AH,0BH          ;置彩色调板
        MOV BH,0H
        MOV BL,10H           ;背景色为黑色
        INT 10H


        DRAW 25, 90, 280, 150, 0EH
        DRAW 65, 260, 230, 300, 0CH
        DRAW 10, 355, 300, 395, 0AH


        ;wel
        MOV BP, OFFSET MSG1
        MOV CX, LEN1
        MOV DH, 7             ;行
        MOV DL, 7             ;列
        MOV BH, 0            ;设置页号
        MOV BL, 01101111B    ;棕底白字
        MOV AL, 1
        MOV AH, 13H
        INT 10H

        ;press
        MOV BP, OFFSET MSG2
        MOV CX, LEN2
        MOV DH, 10            ;行
        MOV DL, 7             ;列
        MOV BH, 0            ;设置页号
        MOV BL, 00001111B    ;黑底白字
        MOV AL, 1
        MOV AH, 13H
        INT 10H

        ;dir
        MOV BP, OFFSET MSG3
        MOV CX, LEN3
        MOV DH, 11            ;行
        MOV DL, 8             ;列
        MOV BH, 0            ;设置页号
        MOV BL, 00001111B    ;黑底白字
        MOV AL, 1
        MOV AH, 13H
        INT 10H

        ;space
        MOV BP, OFFSET MSG4
        MOV CX, LEN4
        MOV DH, 12            ;行
        MOV DL, 8             ;列
        MOV BH, 0            ;设置页号
        MOV BL, 00001111B    ;黑底白字
        MOV AL, 1
        MOV AH, 13H
        INT 10H

        ;esc
        MOV BP, OFFSET MSG5
        MOV CX, LEN5
        MOV DH, 13            ;行
        MOV DL, 8             ;列
        MOV BH, 0            ;设置页号
        MOV BL, 00001111B    ;黑底白字
        MOV AL, 1
        MOV AH, 13H
        INT 10H

        ;sorce
        MOV BP, OFFSET MSG6
        MOV CX, LEN6
        MOV DH, 17            ;行
        MOV DL, 13             ;列
        MOV BH, 0            ;设置页号
        MOV BL, 01001111B    ;红底白字
        MOV AL, 1
        MOV AH, 13H
        INT 10H

        ;design
        MOV BP, OFFSET MSG7
        MOV CX, LEN7
        MOV DH, 23            ;行
        MOV DL, 7             ;列
        MOV BH, 0            ;设置页号
        MOV BL, 00101111B    ;绿底白字
        MOV AL, 1
        MOV AH, 13H
        INT 10H

;以下为绘制贪食蛇四周墙壁，绿色，15*15，每块墙壁四周为黑
        MOV CL, 0
LLLLOOP1:
        ;AX<-AL*SRC
        MOV AL, CL
        MOV CH, 0FH
        MUL CH
        ADD AX, 345
        MOV DX, 105
        DRAW_BLOCK AX, DX, 0AH
        INC CL
        CMP CL, 18
        JNE LLLLOOP1

        MOV CL, 0
LLLLOOP2:
        ;AX<-AL*SRC
        MOV AL, CL
        MOV CH, 0FH
        MUL CH
        ADD AX, 345
        MOV DX, 360
        DRAW_BLOCK AX, DX, 0AH
        INC CL
        CMP CL, 18
        JNE LLLLOOP2

        MOV CL, 0
LLLLOOP3:
        ;AX<-AL*SRC
        MOV AL, CL
        MOV CH, 0FH
        MUL CH
        ADD AX, 120
        MOV DX, 345
        DRAW_BLOCK DX, AX, 0AH
        INC CL
        CMP CL, 16
        JNE LLLLOOP3
        
        MOV CL, 0
LLLLOOP4:
        ;AX<-AL*SRC
        MOV AL, CL
        MOV CH, 0FH
        MUL CH
        ADD AX, 120
        MOV DX, 600
        DRAW_BLOCK DX, AX, 0AH
        INC CL
        CMP CL, 16
        JNE LLLLOOP4
    
        RET
INIT ENDP

CODE ENDS
END START
