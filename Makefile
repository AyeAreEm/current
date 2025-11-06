CC = gcc
CFLAGS = -Wall -Wextra

SRC_CLI = src/cli.c
BIN_CLI = bin/cli.o

SRC_EVAL = src/eval.c
BIN_EVAL = bin/eval.o

SRC_EXPRS = src/exprs.c
BIN_EXPRS = bin/exprs.o

SRC_GEN = src/gen.c
BIN_GEN = bin/gen.o

SRC_KEYWORDS = src/keywords.c
BIN_KEYWORDS = bin/keywords.o

SRC_LEXER = src/lexer.c
BIN_LEXER = bin/lexer.o

SRC_MAIN = src/main.c
BIN_MAIN = bin/main.o

SRC_PARSER = src/parser.c
BIN_PARSER = bin/parser.o

SRC_SEMA = src/sema.c
BIN_SEMA = bin/sema.o

SRC_STMNTS = src/stmnts.c
BIN_STMNTS = bin/stmnts.o

SRC_STRB = src/strb.c
BIN_STRB = bin/strb.o

SRC_TYPECHECK = src/typecheck.c
BIN_TYPECHECK = bin/typecheck.o

SRC_TYPES = src/types.c
BIN_TYPES = bin/types.o

SRC_UTILS = src/utils.c
BIN_UTILS = bin/utils.o

SRC_BUILTIN_DEFS_TXT = src/current_builtin_defs.txt
SRC_BUILTIN_DEFS = src/builtin_defs.c
BIN_BUILTIN_DEFS = bin/builtin_defs.o

BINS = $(BIN_CLI) $(BIN_EVAL) $(BIN_GEN) $(BIN_EXPRS) $(BIN_KEYWORDS) $(BIN_LEXER) $(BIN_MAIN) $(BIN_PARSER) $(BIN_SEMA) $(BIN_STMNTS) $(BIN_STRB) $(BIN_TYPECHECK) $(BIN_TYPES) $(BIN_UTILS) $(BIN_BUILTIN_DEFS)

current: $(BINS)
	$(CC) $(CFLAGS) -o current $(BINS)

$(SRC_BUILTIN_DEFS): $(SRC_BUILTIN_DEFS_TXT)
	xxd -i -n builtin_defs $(SRC_BUILTIN_DEFS_TXT) > src/builtin_defs.c

$(BIN_BUILTIN_DEFS): $(SRC_BUILTIN_DEFS)
	$(CC) $(CFLAGS) -c $(SRC_BUILTIN_DEFS) -o $(BIN_BUILTIN_DEFS)

$(BIN_CLI): $(SRC_CLI)
	$(CC) $(CFLAGS) -c $(SRC_CLI) -o $(BIN_CLI)

$(BIN_EVAL): $(SRC_EVAL)
	$(CC) $(CFLAGS) -c $(SRC_EVAL) -o $(BIN_EVAL)

$(BIN_EXPRS): $(SRC_EXPRS)
	$(CC) $(CFLAGS) -c $(SRC_EXPRS) -o $(BIN_EXPRS)

$(BIN_GEN): $(SRC_GEN) $(BIN_BUILTIN_DEFS)
	$(CC) $(CFLAGS) -c $(SRC_GEN) -o $(BIN_GEN)

$(BIN_KEYWORDS): $(SRC_KEYWORDS)
	$(CC) $(CFLAGS) -c $(SRC_KEYWORDS) -o $(BIN_KEYWORDS)

$(BIN_LEXER): $(SRC_LEXER)
	$(CC) $(CFLAGS) -c $(SRC_LEXER) -o $(BIN_LEXER)

$(BIN_MAIN): $(SRC_MAIN)
	$(CC) $(CFLAGS) -c $(SRC_MAIN) -o $(BIN_MAIN)

$(BIN_PARSER): $(SRC_PARSER)
	$(CC) $(CFLAGS) -c $(SRC_PARSER) -o $(BIN_PARSER)

$(BIN_SEMA): $(SRC_SEMA)
	$(CC) $(CFLAGS) -c $(SRC_SEMA) -o $(BIN_SEMA)

$(BIN_STMNTS): $(SRC_STMNTS)
	$(CC) $(CFLAGS) -c $(SRC_STMNTS) -o $(BIN_STMNTS)

$(BIN_STRB): $(SRC_STRB)
	$(CC) $(CFLAGS) -c $(SRC_STRB) -o $(BIN_STRB)

$(BIN_TYPECHECK): $(SRC_TYPECHECK)
	$(CC) $(CFLAGS) -c $(SRC_TYPECHECK) -o $(BIN_TYPECHECK)

$(BIN_TYPES): $(SRC_TYPES)
	$(CC) $(CFLAGS) -c $(SRC_TYPES) -o $(BIN_TYPES)

$(BIN_UTILS): $(SRC_UTILS)
	$(CC) $(CFLAGS) -c $(SRC_UTILS) -o $(BIN_UTILS)

clean:
	rm -rf bin/*.o current
