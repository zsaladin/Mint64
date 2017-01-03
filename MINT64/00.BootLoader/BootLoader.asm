[ORG 0x00]                  ; 코드의 시작 주소를 0x00으로 설정
[BITS 16]                   ; 이하의 코드는 16비트 코드로 설정

SECTION .text               ; text 섹션(세그먼트)을 정의

jmp 0x07C0:START            ; cs 세그먼트 레지스터에 0x07C0을 복사하면서 START 레이블로 이동

TOTALSECTORCOUNT:   dw  1024    ; 부트 로더를 제외한 MINT64 OS 이미지의 크기
                                ; 최대 1152 섹터(0x90000 byte)까지 가능

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START:
    mov ax, 0x07C0          ; 부트 로더의 시작 주소(0x7C00)를 세그먼트 레지스터 값으로 변환
    mov ds, ax              ; ds 세그먼트 레지스터에 설정
    mov ax, 0xB800          ; 비디오 메모리의 시작 주소(0x0B8000)을 세그먼트 레지스터 값으로 변환
    mov es, ax              ; es 세그먼트 레지스터에 설정
    
    ; 스택을 0x0000:0000 ~ 0x0000:FFFF 영역에 64KB 크기로 생성
    mov ax, 0x0000          ; 스택 세그먼트의 시작 주소(0x0000)을 세그먼트 레지스터 값으로 변환
    mov ss, ax              ; ss 세그먼트 레지스터에 설정
    mov sp, 0xFFFE          ; sp 레지스터의 주소를 0xFFFE로 설정
    mov bp, 0xFFFE          ; bp 레지스터의 주소를 0xFFFE로 설정

    mov si, 0

.SCREENCLEARLOOP:
    mov byte[es:si], 0
    mov byte[es:si+1], 0x0A
    add si, 2

    cmp si, 80 * 25 * 2
    jl .SCREENCLEARLOOP

; 메시지 출력
push MESSAGE1               ; 출력할 메시지의 주소를 스택에 삽입
push 0                      ; 화면 Y 좌표 (0) 을 스택에 삽입
push 0                      ; 화면 X 좌표 (0) 을 스택에 삽입
call PRINTMESSAGE
add sp, 6                   ; 스택 파괴

; OS 이미지를 로딩한다는 메시지 출력
push IMAGELOADINGMESSAGE    ; 출력할 메시지의 주소를 스택에 삽입
push 1                      ; 화면 Y 좌표 (1) 을 스택에 삽입
push 0                      ; 화면 X 좌표 (0) 을 스택에 삽입
call PRINTMESSAGE
add sp, 6                   ; 스택 파괴


RESETDISK:
    ; BIOS Reset Function 호출
    mov ax, 0                       ; BIOS 서비스 번호 0(Reset)
    mov dl, 0                       ; 드라이브 번호(0=Floppy)
    int 0x13                        ; 인터럽트 서비스 수행(Disk I/O)
    jc HANDLEDISKERROR              ; 에러가 발생햇다면 HANDLEDISKERROR 로 이동

    ; 디스크에서 섹터를 읽음
    mov si, 0x1000                  ; 0S 이미지를 복사할 주소(0x010000)를 세그먼트 레지스터 값으로 변환
    mov es, si                      ; es 세그먼트 레지스터 값으로 설정
    mov bx, 0x0000                  ; bx 레지스터에 0x0000을 설정하여 복하살 주소를 0x1000:0000(0x1000)으로 최종 설정
    mov di, word[TOTALSECTORCOUNT]  ; 복사할 OS 이미지의 섹터 수를 di 레지스터에 설정

READDATA:
    ; 모든 섹터를 다 읽었는지 확인
    cmp di, 0                   ; 복사할 OS 이미지의 섹터 수를 0과 비교
    je READEND
    sub di, 0x1

    ; BIOS Read Function 호출
    mov ah, 0x02                ; BIOS 서비스 번호 2(Read Sector)
    mov al, 0x1                ; 읽을 섹터 수는 1
    mov ch, byte[TRACKNUMBER]   ; 읽을 트랙 번호 설정
    mov cl, byte[SECTORNUMBER]  ; 읽을 섹터 번호 설정
    mov dh, byte[HEADNUMBER]    ; 읽을 헤드 번호 설정
    mov dl, 0x00                ; 읽을 드라이브 번호(0=Floppy) 설정
    int 0x13                    ; 인터럽트 서비스 수행(Disk I/O)
    jc HANDLEDISKERROR          ; 에러가 발생했다면 HANDLEDISKERROR 로 이동

    ; 복사할 주소와 트랙, 헤드, 섹터 주소 계산
    add si, 0x0020              ; 512(0x200)바이트만큼 읽었으므로, 이를 세그먼트 레지스터 값으로 변환
    mov es, si                  ; es 세그먼트 레지스터에 더해서 주소를 한 섹터만큼 증가

    mov al, byte[SECTORNUMBER]  ; 섹터 번호를 al 레지스터에 설정
    add al, 0x01                ; 섹터 번호를 1 증가

    mov byte[SECTORNUMBER], al  ; 증가시킨 섹터 번호를 SECTORNUMBER 에 다시 설정
    cmp al, 19                  ; 증가시킨 섹터 번호를 19와 비교
    jl READDATA                 ; 섹터 번호가 19미만이라면 READDATA 로 이동

    xor byte[HEADNUMBER], 0x01  ; 헤드 번호를 0x01과 XOR하여 토글링
    mov byte[SECTORNUMBER], 0x01; 섹터 번호를 다시 1로 설정

    cmp byte[HEADNUMBER], 0x00  ; 헤드 번호를 0x00과 비교
    jne READDATA                ; 헤드 번호가 0이 아니면 READDATA 로 이동

    add byte[TRACKNUMBER], 0x01 ; 트랙 번호를 1 증가
    jmp READDATA                ; READDATA 로 이동

READEND:
    ; OS 이미지가 완료되었다는 메시지 출력
    push LOADINGCOMPLETEMESSAGE ; 출력할 메시지의 주소를 스택에 삽입
    push 1
    push 20
    call PRINTMESSAGE
    add sp, 6

    jmp 0x1000:0x0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   함수 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

HANDLEDISKERROR:                ; 에러를 처리하는 코드
    push DISKERRORMESSAGE
    push 1
    push 20
    call PRINTMESSAGE

    jmp $

PRINTMESSAGE:
    push bp
    mov bp, sp

    push es
    push si
    push di
    push ax
    push cx
    push dx

    ; es 세그먼트 레지스터에 비디오 모드 주소 설정
    mov ax, 0xB800              ; 비디오 메모리 시작 주소(0x0B8000)
    mov es, ax                  ; es 세그먼트 레지스터에 비디오 메모리 시작 주소 설정

    ; Y 좌표를 이용하여 라인 주소를 구함
    mov ax, word[bp+6]          ; 파라미터 2(화면 좌표 Y)를 ax 레지스터에 설정
    mov si, 160                 ; 한 라인의 바이트 수 (2 * 80 컬럼) 을 si 레지스터에 설정
    mul si                      ; ax 레지스터와 si 레지스터를 곱하여 Y 주소 계산
    mov di, ax                  ; ㅖ산된 화면 Y 주소를 di 레지스터에 설정

    ; X 좌표를 이용하여 2를 곱한 후 최정 주소 구함
    mov ax, word[bp+4]          ; 파라미터 1(화면 좌표 X)를 ax 레지스터에 설정
    mov si, 2                   ; 한 문자를 나타내는 바이트 수 (2) fmf si 레지스터에 설정
    mul si                      ; ax 레지스터와 si 레지스터를 곱하여 화면 x 주소 계산
    add di, ax                  ; 화면 Y 주소와 계산된 X 주소를 더해서 실제 비디오 주소를 계산

    ; 출력할 문자열의 주소
    mov si, word[bp+8]          ; 파라미터 3 (출력할 문제열의 주소)

.MESSAGELOOP:                   ; 메세지를 출력하는 루프
    mov cl, byte[si]            ; si 레지스터가 가리키는 문자열 위치에서 한 문자를 cl 레지스터에 복사, cl 레지스터는 cx 레지스터의 하위 1바이트를 의미
    cmp cl, 0                   ; 복사된 문자와 0을 비교
    je .MESSAGEEND              ; 복사된 문자의 값이 0이면 문자열이 종료되었음을 의미한다.

    mov byte[es:di], cl         ; 0이 아니라면 비디오 메모리 주소 0xB800:di 에 문자를 출력
    add si, 1
    add di, 2

    jmp .MESSAGELOOP

.MESSAGEEND:
    pop dx
    pop cx
    pop ax
    pop di
    pop si
    pop es
    pop bp
    ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   데이터 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MESSAGE1:   db 'MINT64 OS Boot Loader Start.', 0
DISKERRORMESSAGE:   db 'DISK error.', 0
IMAGELOADINGMESSAGE: db 'OS Image Loading...', 0
LOADINGCOMPLETEMESSAGE: db 'Complete.', 0

SECTORNUMBER:       db 0x02     ; OS 이미지가 시작하는 섹터 번호를 저장하는 영역
HEADNUMBER:         db 0x00     ; OS 이미지가 시작하는 헤드 번호를 저장하는 영역
TRACKNUMBER:        db 0x00     ; OS 이미지가 시작하는 트랙 번호를 저장하는 영역

times 510 - ( $ - $$ )  db  0x00

db 0x55                     ; 1바이트를 선언하고 값은 0x55
db 0xAA                     ; 1바이트를 선언학고 값은 0xAA
                            ; 511, 512에 0x55, 0xAA를 써서 부트 섹터로 표기
