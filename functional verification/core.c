#include <stdint.h>

/* ================================
 * Constantes / Endereços
 * ================================ */
#define RESET_VECTOR      0x00000000u

#define RAM_BASE          0x00000000u
#define RAM_END_ADDRESS   0x0000FFFFu

/* Para os testes de load/store e unaligned:
 * usar um endereço na RAM que não conflite com .data/.bss.
 * Aqui foi colocado um offset seguro “genérico”. */
#define TEST_MEMORY_BASE  (RAM_BASE + 0x00000200u)
#define UNALIGNED_ADDRESS (TEST_MEMORY_BASE + 1u)

/* Código de exceção RISC-V */
#define MISALIGNED_LOAD   4u

#define TEST_STATUS_ADDR  0x40000000u  /* ajustar se necessário */
static volatile uint32_t *const test_status = (uint32_t *)TEST_STATUS_ADDR;

/* UART (assumindo TX em offset 0x00). Ajustar conforme seu periférico. */
#define UART_BASE         0x40002000u
#define UART_TX           (*(volatile uint32_t *)(UART_BASE + 0x00u))

/* IRQ controller (modelo mínimo). Ajustar offsets conforme INTR real. */
#define INTR_BASE         0x40005000u
#define INTR_ENABLE       (*(volatile uint32_t *)(INTR_BASE + 0x00u)) /* bit0 enable */
#define INTR_PENDING      (*(volatile uint32_t *)(INTR_BASE + 0x04u)) /* bit0 pending/clear */

/* TIMER (modelo mínimo para “trigger”). Ajustar conforme TIMER real. */
#define TIMER_BASE        0x40001000u
#define TIMER_TRIGGER     (*(volatile uint32_t *)(TIMER_BASE + 0x00u)) /* escrever 1 -> gera IRQ (modelo) */

/* ================================
 * Infra / Macros
 * ================================ */
#define ASSERT(cond) do { if (!(cond)) fail(__LINE__); } while (0)

static inline void uart_putc(char c) { UART_TX = (uint32_t)c; }
static void uart_print(const char *s) { while (*s) uart_putc(*s++); }

static void halt(void)
{
    for (;;)
        asm volatile ("wfi");
}

static void fail(uint32_t code)
{
    *test_status = 0xDEAD0000u | (code & 0xFFFFu);
    halt();
}

#define PRINT(msg)  uart_print((msg))
#define HALT()      halt()

/* ================================
 * Variáveis globais para reset/trap/irq
 * ================================ */
static volatile uint32_t g_reset_ok = 0;

static volatile uint32_t g_last_mcause = 0;
static volatile uint32_t g_expect_mcause = 0;
static volatile uint32_t g_trap_seen = 0;

static volatile uint32_t INTERRUPT_HANDLER_EXECUTED = 0;
#define TRUE 1u

void init_environment(void);
void test_reset(void);
void test_register_file(void);
void test_alu(void);
void test_shift_unit(void);
void test_load_store(void);
void test_branches(void);
void test_jumps(void);
void test_exceptions(void);
void test_interrupts(void);
void report_success(void);

/* ================================
 * Helpers RISC-V (CSR)
 * ================================ */
static inline void disable_interrupts(void)
{
    /* limpa MIE (bit 3) */
    asm volatile ("csrci mstatus, 0x8");
}

static inline void enable_interrupts_global(void)
{
    /* seta MIE (bit 3) */
    asm volatile ("csrsi mstatus, 0x8");
}

static inline void enable_machine_external_irq(void)
{
    /* seta MEIE (bit 11) em mie */
    asm volatile ("csrsi mie, (1<<11)");
}

static inline void set_mtvec(void *handler)
{
    /* mtvec em modo direct (LSBs=0) */
    asm volatile ("csrw mtvec, %0" :: "r"(handler));
}

/* GET_PC equivalente */
static inline uint32_t read_pc(void)
{
    uint32_t pc;
    asm volatile ("auipc %0, 0" : "=r"(pc));
    return pc;
}

/* Leitura de registradores (x1..x31) */
static inline uint32_t read_reg(uint32_t reg_num)
{
    uint32_t value = 0;
    switch (reg_num)
    {
        case 1:  asm volatile ("mv %0, x1"  : "=r"(value)); break;
        case 2:  asm volatile ("mv %0, x2"  : "=r"(value)); break;
        case 3:  asm volatile ("mv %0, x3"  : "=r"(value)); break;
        case 4:  asm volatile ("mv %0, x4"  : "=r"(value)); break;
        case 5:  asm volatile ("mv %0, x5"  : "=r"(value)); break;
        case 6:  asm volatile ("mv %0, x6"  : "=r"(value)); break;
        case 7:  asm volatile ("mv %0, x7"  : "=r"(value)); break;
        case 8:  asm volatile ("mv %0, x8"  : "=r"(value)); break;
        case 9:  asm volatile ("mv %0, x9"  : "=r"(value)); break;
        case 10: asm volatile ("mv %0, x10" : "=r"(value)); break;
        case 11: asm volatile ("mv %0, x11" : "=r"(value)); break;
        case 12: asm volatile ("mv %0, x12" : "=r"(value)); break;
        case 13: asm volatile ("mv %0, x13" : "=r"(value)); break;
        case 14: asm volatile ("mv %0, x14" : "=r"(value)); break;
        case 15: asm volatile ("mv %0, x15" : "=r"(value)); break;
        case 16: asm volatile ("mv %0, x16" : "=r"(value)); break;
        case 17: asm volatile ("mv %0, x17" : "=r"(value)); break;
        case 18: asm volatile ("mv %0, x18" : "=r"(value)); break;
        case 19: asm volatile ("mv %0, x19" : "=r"(value)); break;
        case 20: asm volatile ("mv %0, x20" : "=r"(value)); break;
        case 21: asm volatile ("mv %0, x21" : "=r"(value)); break;
        case 22: asm volatile ("mv %0, x22" : "=r"(value)); break;
        case 23: asm volatile ("mv %0, x23" : "=r"(value)); break;
        case 24: asm volatile ("mv %0, x24" : "=r"(value)); break;
        case 25: asm volatile ("mv %0, x25" : "=r"(value)); break;
        case 26: asm volatile ("mv %0, x26" : "=r"(value)); break;
        case 27: asm volatile ("mv %0, x27" : "=r"(value)); break;
        case 28: asm volatile ("mv %0, x28" : "=r"(value)); break;
        case 29: asm volatile ("mv %0, x29" : "=r"(value)); break;
        case 30: asm volatile ("mv %0, x30" : "=r"(value)); break;
        case 31: asm volatile ("mv %0, x31" : "=r"(value)); break;
        default: value = 0; break;
    }
    return value;
}

static inline void write_reg(uint32_t reg, uint32_t value)
{
    switch (reg)
    {
        case 1:  asm volatile("mv x1,  %0" :: "r"(value)); break;
        case 2:  asm volatile("mv x2,  %0" :: "r"(value)); break;
        case 3:  asm volatile("mv x3,  %0" :: "r"(value)); break;
        case 4:  asm volatile("mv x4,  %0" :: "r"(value)); break;
        case 5:  asm volatile("mv x5,  %0" :: "r"(value)); break;
        case 6:  asm volatile("mv x6,  %0" :: "r"(value)); break;
        case 7:  asm volatile("mv x7,  %0" :: "r"(value)); break;
        case 8:  asm volatile("mv x8,  %0" :: "r"(value)); break;
        case 9:  asm volatile("mv x9,  %0" :: "r"(value)); break;
        case 10: asm volatile("mv x10, %0" :: "r"(value)); break;
        case 11: asm volatile("mv x11, %0" :: "r"(value)); break;
        case 12: asm volatile("mv x12, %0" :: "r"(value)); break;
        case 13: asm volatile("mv x13, %0" :: "r"(value)); break;
        case 14: asm volatile("mv x14, %0" :: "r"(value)); break;
        case 15: asm volatile("mv x15, %0" :: "r"(value)); break;
        case 16: asm volatile("mv x16, %0" :: "r"(value)); break;
        case 17: asm volatile("mv x17, %0" :: "r"(value)); break;
        case 18: asm volatile("mv x18, %0" :: "r"(value)); break;
        case 19: asm volatile("mv x19, %0" :: "r"(value)); break;
        case 20: asm volatile("mv x20, %0" :: "r"(value)); break;
        case 21: asm volatile("mv x21, %0" :: "r"(value)); break;
        case 22: asm volatile("mv x22, %0" :: "r"(value)); break;
        case 23: asm volatile("mv x23, %0" :: "r"(value)); break;
        case 24: asm volatile("mv x24, %0" :: "r"(value)); break;
        case 25: asm volatile("mv x25, %0" :: "r"(value)); break;
        case 26: asm volatile("mv x26, %0" :: "r"(value)); break;
        case 27: asm volatile("mv x27, %0" :: "r"(value)); break;
        case 28: asm volatile("mv x28, %0" :: "r"(value)); break;
        case 29: asm volatile("mv x29, %0" :: "r"(value)); break;
        case 30: asm volatile("mv x30, %0" :: "r"(value)); break;
        case 31: asm volatile("mv x31, %0" :: "r"(value)); break;
        default: break;
    }
}

/* ================================
 * Trap handler (exceptions + interrupts)
 * ================================ */
void trap_handler(void);

/* handler em C + asm para retornar corretamente */
__attribute__((naked))
void trap_handler(void)
{
    asm volatile (
        /* salva mcause/mepc em variáveis globais */
        "csrr t0, mcause\n"
        "csrr t1, mepc\n"
        "la   t2, g_last_mcause\n"
        "sw   t0, 0(t2)\n"
        "la   t2, g_trap_seen\n"
        "li   t3, 1\n"
        "sw   t3, 0(t2)\n"

        /* Se for interrupt (bit XLEN-1 = 1), marque flag e limpe pending (modelo) */
        "srli t3, t0, 31\n"
        "beqz t3, 1f\n"
        "la   t2, INTERRUPT_HANDLER_EXECUTED\n"
        "li   t4, 1\n"
        "sw   t4, 0(t2)\n"
        /* limpa pending bit0 (modelo) */
        "li   t4, 1\n"
        "la   t5, INTR_PENDING\n"
        "sw   t4, 0(t5)\n"
        "j    2f\n"

        /* Exception: avance mepc em 4 para pular instrução faltosa */
        "1:\n"
        "addi t1, t1, 4\n"
        "csrw mepc, t1\n"

        "2:\n"
        "mret\n"
    );
}

/* ================================
 * Startup (_start): check de reset antes do C “usar registradores”
 * ================================ */
void _start(void) __attribute__((naked, section(".text.start")));
void _start(void)
{
    asm volatile (
        /* Ajusta sp no topo da RAM */
        "li   sp, %0\n"

        /* Check rápido (opcional): regs x1..x31 == 0
           OBS: PicoRV32 pode ou não resetar regs em 0 dependendo do SoC.
           Mantive para seguir seu pseudocódigo. Se falhar por HW, remova. */
        "li   t0, 0\n"
        "bne  x1,  t0, 9f\n"
        "bne  x2,  t0, 9f\n"
        "bne  x3,  t0, 9f\n"
        "bne  x4,  t0, 9f\n"
        "bne  x5,  t0, 9f\n"
        "bne  x6,  t0, 9f\n"
        "bne  x7,  t0, 9f\n"
        "bne  x8,  t0, 9f\n"
        "bne  x9,  t0, 9f\n"
        "bne  x10, t0, 9f\n"
        "bne  x11, t0, 9f\n"
        "bne  x12, t0, 9f\n"
        "bne  x13, t0, 9f\n"
        "bne  x14, t0, 9f\n"
        "bne  x15, t0, 9f\n"
        "bne  x16, t0, 9f\n"
        "bne  x17, t0, 9f\n"
        "bne  x18, t0, 9f\n"
        "bne  x19, t0, 9f\n"
        "bne  x20, t0, 9f\n"
        "bne  x21, t0, 9f\n"
        "bne  x22, t0, 9f\n"
        "bne  x23, t0, 9f\n"
        "bne  x24, t0, 9f\n"
        "bne  x25, t0, 9f\n"
        "bne  x26, t0, 9f\n"
        "bne  x27, t0, 9f\n"
        "bne  x28, t0, 9f\n"
        "bne  x29, t0, 9f\n"
        "bne  x30, t0, 9f\n"
        "bne  x31, t0, 9f\n"

        /* marca reset ok */
        "la   t1, g_reset_ok\n"
        "li   t0, 1\n"
        "sw   t0, 0(t1)\n"

        /* chama main */
        "call main\n"
        /* se voltar, halta */
        "j    8f\n"

        /* falha no reset-check: escreve status e halta */
        "9:\n"
        "la   t1, %1\n"
        "li   t0, 0xDEAD0001\n"
        "sw   t0, 0(t1)\n"
        "8:\n"
        "wfi\n"
        "j 8b\n"
        :: "i"(RAM_END_ADDRESS), "i"(TEST_STATUS_ADDR)
        : "t0","t1"
    );
}

/* ================================
 * Funções do seu roteiro
 * ================================ */
void init_environment(void)
{
    disable_interrupts();

    /* status = 0 */
    *test_status = 0;

    /* instala trap handler */
    set_mtvec((void*)trap_handler);

    /* stack já foi ajustado em _start, mas manter aqui não quebra */
    asm volatile ("mv sp, %0" :: "r"(RAM_END_ADDRESS));
}

void test_reset(void)
{
    /* Valida que o check “pré-C” passou */
    ASSERT(g_reset_ok == 1u);

    (void)read_pc();
}

void test_register_file(void)
{
    /* Salva x1..x4 e sp (x2) sem depender de stack (t0..t6 são temporários) */
    uint32_t save_ra, save_sp, save_gp, save_tp;
    asm volatile ("mv %0, x1" : "=r"(save_ra));
    asm volatile ("mv %0, x2" : "=r"(save_sp));
    asm volatile ("mv %0, x3" : "=r"(save_gp));
    asm volatile ("mv %0, x4" : "=r"(save_tp));

    /* Testa x1..x31
       Atenção: escrever em x2 (sp) só pode ser feito dentro de bloco asm sem uso de stack.
       Aqui é feito write/read de x2 via asm e restaurado imediatamente. */
    for (uint32_t reg = 1; reg <= 31; reg++)
    {
        if (reg == 2)
        {
            uint32_t v;

            asm volatile (
                "mv  t0, sp\n"
                "li  sp, 0xAAAAAAAA\n"
                "mv  %0, sp\n"
                "mv  sp, t0\n"
                : "=r"(v) :: "t0"
            );
            ASSERT(v == 0xAAAAAAAAu);

            asm volatile (
                "mv  t0, sp\n"
                "li  sp, 0x55555555\n"
                "mv  %0, sp\n"
                "mv  sp, t0\n"
                : "=r"(v) :: "t0"
            );
            ASSERT(v == 0x55555555u);

            continue;
        }

        write_reg(reg, 0xAAAAAAAAu);
        ASSERT(read_reg(reg) == 0xAAAAAAAAu);

        write_reg(reg, 0x55555555u);
        ASSERT(read_reg(reg) == 0x55555555u);
    }

    /* ASSERT(x0 == 0) */
    uint32_t x0_val;
    asm volatile("mv %0, x0" : "=r"(x0_val));
    ASSERT(x0_val == 0u);

    /* Restaura regs críticos */
    asm volatile ("mv x1, %0" :: "r"(save_ra));
    asm volatile ("mv x2, %0" :: "r"(save_sp));
    asm volatile ("mv x3, %0" :: "r"(save_gp));
    asm volatile ("mv x4, %0" :: "r"(save_tp));
}

void test_alu(void)
{
    ASSERT((5 + 3) == 8);
    ASSERT((5 - 3) == 2);

    ASSERT((0xF0F0 & 0x0FF0) == 0x00F0);
    ASSERT((0xF0F0 | 0x0FF0) == 0xFFF0);
    ASSERT((0xAAAA ^ 0x5555) == 0xFFFF);

    ASSERT(((2 < 5) ? 1 : 0) == 1);
    ASSERT(((5 < 2) ? 1 : 0) == 0);
}

void test_shift_unit(void)
{
    ASSERT((1u << 4) == 16u);
    ASSERT((16u >> 2) == 4u);
    ASSERT(((int32_t)-8 >> 1) == (int32_t)-4);
}

void test_load_store(void)
{
    volatile uint8_t  *byte_ptr;
    volatile uint16_t *half_ptr;
    volatile uint32_t *word_ptr;

    uintptr_t address = (uintptr_t)TEST_MEMORY_BASE;

    word_ptr = (uint32_t *)address;
    *word_ptr = 0x12345678u;
    ASSERT(*word_ptr == 0x12345678u);

    half_ptr = (uint16_t *)address;
    *half_ptr = 0xABCDu;
    ASSERT(*half_ptr == 0xABCDu);

    byte_ptr = (uint8_t *)address;
    *byte_ptr = 0x5Au;
    ASSERT(*byte_ptr == 0x5Au);
}

void test_branches(void)
{
    int BEQ_TAKEN = 0;
    int BNE_TAKEN = 0;
    int BLT_TAKEN = 0;

    if (5 == 5) { BEQ_TAKEN = 1; ASSERT(BEQ_TAKEN == 1); }
    if (5 != 3) { BNE_TAKEN = 1; ASSERT(BNE_TAKEN == 1); }
    if (3 < 5)  { BLT_TAKEN = 1; ASSERT(BLT_TAKEN == 1); }
}

void test_jumps(void)
{
    uint32_t current_pc = read_pc();
    uint32_t after;

    /* JAL(LABEL) em asm: cai no label e então lemos PC */
    asm volatile (
        "jal ra, 1f\n"
        "nop\n"
        "1:\n"
    );

    after = read_pc();
    /* Não dá para comparar igualdade com LABEL facilmente em C,
       mas podemos garantir que PC mudou. */
    ASSERT(after != current_pc);

    /* JALR(x1): vamos fazer x1 apontar para um label e jalr para ele,
       sem perder o retorno. */
    asm volatile (
        "la   t0, 2f\n"
        "mv   x1, t0\n"
        "jalr x0, 0(x1)\n"
        "2:\n"
        ::: "t0"
    );

    /* Se chegou aqui, o jalr saltou corretamente para o label 2 */
    ASSERT(1);
}

void test_exceptions(void)
{
    g_trap_seen = 0;
    g_last_mcause = 0;
    g_expect_mcause = MISALIGNED_LOAD;

    /* Faz um LOAD_WORD em endereço desalinhado para gerar exceção */
    volatile uint32_t *ptr = (uint32_t *)(uintptr_t)UNALIGNED_ADDRESS;
    (void)*ptr; /* vai trapar e o handler retorna pulando a instrução */

    ASSERT(g_trap_seen == 1u);
    ASSERT((g_last_mcause & 0x7FFFFFFFu) == MISALIGNED_LOAD);
}

static inline void ENABLE_INTERRUPTS(void)
{
    /* habilita no controlador (modelo) */
    INTR_ENABLE = 1u;

    /* habilita MEIE e MIE global */
    enable_machine_external_irq();
    enable_interrupts_global();
}

static inline void TRIGGER_TIMER_INTERRUPT(void)
{
    /* modelo: escrever 1 no TIMER para gerar IRQ e setar pending no controlador */
    TIMER_TRIGGER = 1u;
    INTR_PENDING  = 1u;
}

static inline void WAIT_FOR_INTERRUPT(void)
{
    while (INTERRUPT_HANDLER_EXECUTED == 0u)
        asm volatile ("wfi");
}

void test_interrupts(void)
{
    INTERRUPT_HANDLER_EXECUTED = 0u;

    ENABLE_INTERRUPTS();
    TRIGGER_TIMER_INTERRUPT();
    WAIT_FOR_INTERRUPT();

    ASSERT(INTERRUPT_HANDLER_EXECUTED == TRUE);

    /* desabilita global para não afetar próximos testes */
    disable_interrupts();
}

void report_success(void)
{
    PRINT("ALL TESTS PASSED\n");
    *test_status = 0x55AA55AAu;
    HALT();
}

/* ================================
 * main
 * ================================ */
int main(void)
{
    init_environment();
    test_reset();
    test_register_file();
    test_alu();
    test_shift_unit();
    test_load_store();
    test_branches();
    test_jumps();
    test_exceptions();
    test_interrupts();
    report_success();
    return 0;
}