# AXI4-Lite Interrupt Controller (5-Channel)

## 📌 Introdução

Este repositório contém o subsistema de gerenciamento de interrupções de alto desempenho utilizado no SoC baseado em PicoRV32, construído sobre a arquitetura da Ultra-Embedded.

O controlador foi **expandido de 4 para 5 canais** de interrupção para suportar completamente os periféricos do sistema: **GPIO, Timer, UART, SPI e I2C**.

### Arquivos do Subsistema

- **irq_ctrl.v** - Módulo principal do controlador
- **irq_ctrl_defs.v** - Definições de endereços e constantes

---

## 📋 1. Visão Geral

O `irq_ctrl` atua como **mediador entre os periféricos do sistema e a CPU PicoRV32**.

### Responsabilidades

- ✓ Capturar pulsos de interrupção assíncronos
- ✓ Realizar latching (travamento) dos eventos
- ✓ Priorizar automaticamente as interrupções
- ✓ Manter o sinal ativo até que o processador reconheça o evento

**Diferencial**: Este módulo garante que pulsos curtos **não sejam perdidos** pela CPU, diferente de controladores simples.

---

## 🛠️ 2. Principais Funcionalidades

### ✅ Interface AXI4-Lite Nativa
- Barramento de 32 bits (dados e endereços)
- Handshakes completos para leitura e escrita
- Totalmente compatível com arquitetura AXI4-Lite

### ✅ Lógica de Persistência (Latching)
- O registrador `irq_pending_q` mantém interrupções pendentes
- Pulsos rápidos não são perdidos
- A interrupção permanece ativa até ACK explícito

### ✅ Codificador de Prioridade
- Prioridade fixa por hardware
- **Bit 0 possui a maior prioridade**
- O vetor retorna automaticamente a interrupção ativa mais prioritária

### ✅ Gerenciamento Atômico
- Registradores dedicados para **Set (SIE)** e **Clear (CIE)**
- Evita operações de leitura-modificação-escrita
- Ideal para firmware multitarefa

### ✅ Mestre Global de Interrupções
- Registrador **MER** (Master Enable Register)
- Permite silenciar todas as interrupções com um único bit
- Bit 0 controla habilitação global

---

## 🗺️ 3. Mapa de Registradores

As definições de endereços estão localizadas no arquivo **irq_ctrl_defs.v**.

Todos os registradores operam com **5 bits (4:0)**, compatíveis com os 5 canais de interrupção.

| Offset | Registro | Acesso | Descrição |
|--------|----------|--------|-----------|
| 0x00 | ISR | R/W | Interrupt Status – Status bruto das linhas |
| 0x04 | IPR | R | Interrupt Pending – Pendentes e habilitadas |
| 0x08 | IER | R/W | Interrupt Enable – Máscara individual |
| 0x0C | IAR | W | Interrupt Acknowledge – Limpa a interrupção |
| 0x10 | SIE | W | Set Interrupt Enable – Habilita sem RMW |
| 0x14 | CIE | W | Clear Interrupt Enable – Desabilita com segurança |
| 0x18 | IVR | R | Interrupt Vector – Índice (0-4) prioritário |
| 0x1C | MER | R/W | Master Enable Register – Habilitação global |

---

## 🔌 4. Conexões no SoC

### Mapeamento de Canais

No arquivo `soc_top.v`, o controlador é instanciado com o seguinte mapeamento:

```
irq[0] → GPIO
irq[1] → Timer
irq[2] → UART
irq[3] → SPI
irq[4] → I2C
```

### Reset

O módulo utiliza **reset ativo em nível ALTO**:

```verilog
rst_i = !aresetn  // No topo do SoC
```

### Sinais de Interrupção

#### Entradas (5 canais)
- `interrupt0_i` - GPIO
- `interrupt1_i` - Timer
- `interrupt2_i` - UART
- `interrupt3_i` - SPI
- `interrupt4_i` - I2C

#### Saída
- `intr_o` - Conectado direto ao PicoRV32

---

## ⚙️ 5. Fluxo de Tratamento de Interrupção (Firmware)

### Sequência de Operação

1. A CPU recebe o sinal `intr_o`
2. Ler o registrador **IVR** para identificar a origem
3. Executar o tratamento correspondente
4. Escrever no registrador **IAR** para limpar a interrupção
5. O controlador libera a linha automaticamente

### ⚠️ Importante

Se o **IAR** não for escrito corretamente, a interrupção **permanecerá ativa**.

---

## 📌 Especificações Técnicas

| Parâmetro | Valor |
|-----------|-------|
| Interface | AXI4-Lite |
| Bus de Dados | 32 bits |
| Bus de Endereços | 32 bits |
| Canais de Interrupção | 5 |
| Modo de Prioridade | Fixa por hardware |
| Reset | Ativo em nível alto |
| Compatibilidade | PicoRV32 SoC |

---

## 📄 Referências

- https://github.com/ultraembedded/riscv_soc
- Ultra-Embedded: Copyright 2014-2019
- Licença: BSD
- Contato: admin@ultra-embedded.com
