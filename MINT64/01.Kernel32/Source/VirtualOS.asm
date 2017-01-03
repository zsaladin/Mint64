[ORG 0x00]
[BITS 16]

SECTION .text

jmp 0x1000:START

SECTORCOUNT:        dw 0x0000
TOTALSECTORCOUNT:   equ 1024

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

START:
    mov ax, cs
    mov ds, ax
    mov ax, 0xB800
    mov es, ax
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;   각 섹터 별로 코드를 생성
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    %assign i   0             ; i 라는 변수를 지정하고 0 으로 초기화
    %rep TOTALSECTORCOUNT   ; TOTALSECTORCOUNT 에 저장된 값만큼 아래 코드를 반복
        %assign i   i+1       ; i 를 1 증가
        
        ; 현재 실행 중인 코드가 포함된 섹터의 위치를 화면 좌표로 변환
        mov ax, 2
        mul word[SECTORCOUNT]
        mov si, ax
        mov byte[es:si + (160 * 2)], ('0' + (i % 10))
        add word[SECTORCOUNT], 1
        
        %if i == TOTALSECTORCOUNT
            jmp $
        %else
            jmp (0x1000 + i * 0x20): 0x0000
        %endif

        times (512 - ($-$$) % 512) db 0x00
    %endrep