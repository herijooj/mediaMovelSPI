#!/bin/bash

# Implementado por Eduardo Machado (2015)
# Modified by Heric Camargo (2024)

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

set_colors() {
    RED='\033[1;31m'
    GREEN='\033[1;32m'
    YELLOW='\033[1;93m'
    BLUE='\033[1;36m'
    PURPLE='\033[1;35m'
    CYAN='\033[0;36m'
    GRAY='\033[0;90m'
    BOLD='\033[1m'
    NC='\033[0m'
}

if [ -t 1 ] && ! grep -q -e '--no-color' <<<"$@"
then
    set_colors
fi

ensure_output_dir() {
    local output_dir=$1
    if [ ! -d "$output_dir" ]; then
        mkdir -p "$output_dir"
        if [ $? -ne 0 ]; then
            echo "ERRO: Não foi possível criar o diretório de saída: $output_dir"
            exit 1
        fi
    fi
}

process_single_file() {
    local ARQ_CTL_IN=$1
    local OUTPUT_DIR=$2

    echo -e "\n${BOLD}${PURPLE}=== Processando arquivo: ${CYAN}$(basename "$ARQ_CTL_IN")${NC} ===\n"

    ARQ_BIN_IN="$(dirname $ARQ_CTL_IN)/$(grep dset $ARQ_CTL_IN | tr -s " " | cut -d" " -f2 | sed -e s/\\^//g)"
    ARQ_BIN_OUT="${OUTPUT_DIR}/$(basename $ARQ_BIN_IN .bin)_mmSPI${N_MESES_SPI}.bin"

    # Extrair parâmetros do arquivo de controle
    echo -e "${GRAY}[INFO]${NC} Extraindo parâmetros do arquivo de controle..."
    NX=$(cat ${ARQ_CTL_IN} | grep xdef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    NY=$(cat ${ARQ_CTL_IN} | grep ydef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    NZ=$(cat ${ARQ_CTL_IN} | grep zdef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    NT=$(cat ${ARQ_CTL_IN} | grep tdef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    UNDEF=$(cat ${ARQ_CTL_IN} | grep undef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    VAR=$(grep -A1 -i -w '^vars' ${ARQ_CTL_IN} | tail -n1 | awk '{print $1}')

    echo -e "${GRAY}[INFO]${NC} Executando média móvel..."

    # Loop para cada intervalo
    for N_MESES_SPI in "${MEDIA_MOVEL_INTERVALS[@]}"; do
        ARQ_BIN_OUT="${OUTPUT_DIR}/$(basename $ARQ_BIN_IN .bin)_mmSPI${N_MESES_SPI}.bin"
        if $SCRIPT_DIR/bin/media_movel ${ARQ_BIN_IN} ${NX} ${NY} ${NZ} ${NT} ${UNDEF} ${N_MESES_SPI} ${ARQ_BIN_OUT}; then
            echo -e "${GREEN}[SUCESSO]${NC} Média móvel ${N_MESES_SPI} calculada"
        else
            echo -e "${RED}[FALHA]${NC} Erro na média móvel ${N_MESES_SPI}"
            exit 1
        fi

        ARQ_CTL_OUT="${OUTPUT_DIR}/$(basename $ARQ_CTL_IN .ctl)_mmSPI${N_MESES_SPI}.ctl"
        cp $ARQ_CTL_IN $ARQ_CTL_OUT
        sed -i "s#$(basename $ARQ_BIN_IN .bin)#$(basename $ARQ_BIN_OUT .bin)#g" ${ARQ_CTL_OUT}
    done

    echo -e "${GRAY}─────────────────────────────────────────${NC}"
}

print_usage() {
    echo -e "${BOLD}USO:${NC}"
    echo -e "  ${GREEN}mediaMovelSPI${NC} ${YELLOW}[ENTRADA]${NC} ${CYAN}[OPÇÕES]${NC}\n"
    
    echo -e "${BOLD}ENTRADA:${NC}"
    echo -e "  ${YELLOW}ARQ_CTL_ENTRADA${NC}  Arquivo .ctl individual para processar"
    echo -e "  ${YELLOW}DIRETORIO${NC}        Diretório contendo arquivos .ctl para processamento em lote\n"
    
    echo -e "${BOLD}OPÇÕES:${NC}"
    echo -e "  ${CYAN}-o, --output${NC} DIR   Define o diretório de saída"
    echo -e "  ${CYAN}-m, --meses${NC} NUMS   Intervalor customizado de meses (ex: 1 3 6)"
    echo -e "  ${CYAN}-h, --help${NC}         Mostra esta mensagem de ajuda"    
    echo -e "${BOLD}OBSERVAÇÕES:${NC}"
    echo -e "  • Se ${CYAN}-o${NC} não for especificado, será usado o diretório '${GRAY}[entrada]_mmSPI${NC}'"
    echo -e "  • O número de meses SPI é extraído automaticamente do nome do arquivo\n"
    
    echo -e "${BOLD}EXEMPLO:${NC}"
    echo -e "  ${GREEN}mediaMovelSPI${NC} ${YELLOW}dados/spi3.ctl${NC} ${CYAN}-o saida/processado${NC}\n"
}

OUTPUT_DIR=""
MEDIA_MOVEL_INTERVALS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -m|--meses)
            shift
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                MEDIA_MOVEL_INTERVALS+=("$1")
                shift
            done
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            INPUT="$1"
            shift
            ;;
    esac
done

# Se nenhum intervalo for passado, usar padrao
if [ ${#MEDIA_MOVEL_INTERVALS[@]} -eq 0 ]; then
    MEDIA_MOVEL_INTERVALS=(1 3 6 9 12 24 48 60)
fi

if [ -z "$INPUT" ]; then
    echo -e "${RED}[FALHA]${NC} Arquivo de entrada não especificado!"
    print_usage
    exit 1
fi

if [ -z "$OUTPUT_DIR" ]; then
    #output_dir vai ser uma nova pasta com o nome do arquivo de entrada + _mmSPI
    OUTPUT_DIR="$(pwd)/$(basename "$INPUT" .ctl)_mmSPI"
fi

ensure_output_dir "$OUTPUT_DIR"

if [ -d "$INPUT" ]; then
    echo "Processando diretório: $INPUT"
    for arquivo in "$INPUT"/*.ctl; do
        if [ -f "$arquivo" ]; then
            process_single_file "$arquivo" "$OUTPUT_DIR"
        fi
    done
elif [ -f "$INPUT" ]; then
    process_single_file "$INPUT" "$OUTPUT_DIR"
else
    echo "${RED}[FALHA]${NC}ERRO: '$INPUT' não é um arquivo ou diretório válido"
    exit 1
fi
