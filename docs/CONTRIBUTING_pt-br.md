# Contribuindo com o Cerbero

Obrigado pelo interesse em contribuir! Este guia cobre tudo o que você precisa para compilar, testar e enviar alterações.

---

## Compilando

1. Abra o RAD Studio 12 Athens.
2. Abra `tests/Cerbero.Tests.dproj` (para o runner de testes) ou o `.dproj` principal em `src/`.
3. Selecione **Build > Build All** (`Shift+F9`).
4. Os arquivos compilados (`.dcu`, `.exe`) vão para `bin/` e `dcu/` — ambos ignorados pelo git.

Não é necessário nenhum pacote externo. A biblioteca depende apenas de units da RTL do Delphi: `System.Hash`, `System.JSON` e `System.NetEncoding`.

---

## Executando os Testes

Os testes utilizam o framework **DUnitX** e são executados via console runner.

```
cd tests/
Cerbero.Tests.exe --format=plain
```

Todos os testes devem passar antes de submeter um pull request. A saída deve terminar com:

```
Tests passed: N  Failed: 0  Errors: 0
```

Os arquivos de teste seguem a convenção `Cerbero.Tests.<Modulo>.pas` dentro de `tests/`. Mocks ficam em `tests/mocks/` com o prefixo `Cerbero.Mock.<Tipo>.pas`.

---

## Submetendo um Pull Request

1. Faça um fork do repositório e crie um branch de feature a partir de `main`:
   ```
   git checkout -b feat/minha-feature
   ```
2. Implemente as mudanças. Siga as convenções de código abaixo.
3. Execute todos os testes e confirme que não há falhas.
4. Faça o commit usando [Conventional Commits](https://www.conventionalcommits.org/) em português:
   ```
   feat(jwt): adiciona suporte a RS256
   fix(verify): corrige leitura de claim booleana vazia
   ```
5. Abra um pull request contra `main`. Preencha a descrição do PR explicando **o que** mudou e **por quê**.

---

## Convenções de Código

### Nomenclatura

| Elemento | Prefixo | Exemplo |
|----------|---------|---------|
| Classe | `T` + prefixo do projeto | `TCerberoBuilder` |
| Interface | `I` + prefixo do projeto | `ICerberoClaims` |
| Exceção | `E` + prefixo do projeto | `ECerberoExpiredToken` |
| Parâmetro de método | `A` | `ASecret`, `ASubject` |
| Variável local | `L` | `LToken`, `LClaims` |
| Campo de classe | `F` | `FSecret`, `FExpiry` |

Todos os nomes usam PascalCase. Interfaces devem ter GUID único — nunca copiar de outra interface.

### Declarações

- Declare variáveis locais na seção `var` do método, não inline (`var x :=`).
- Extraia magic numbers e literais de string para seções `const` com nome descritivo.

### Cláusula `uses`

- Units usadas na declaração de tipos ficam na seção `interface`.
- Units usadas apenas na implementação ficam na seção `implementation`.
- Ordem: RTL/VCL (`System.*`) → libs externas → units do Cerbero.
- Não reordenar entradas `uses` existentes ao editar um arquivo — altere apenas o necessário.

### Formatação

- Indentação: **2 espaços** (sem tabs).
- Encoding: UTF-8 com BOM onde já existir — não alterar.
- Seguir o [Delphi Style Guide da Embarcadero](https://docwiki.embarcadero.com/RADStudio/en/Delphi_Style_Guide).

### Tratamento de Erros

- `try/finally` é obrigatório sempre que um objeto é alocado e precisa ser liberado.
- Sem blocos `except` vazios (`except end`). Sempre logar ou relançar.
- Evite capturar a classe genérica `Exception` sem um tratamento adequado.

---

## Estrutura do Projeto

```
Cerbero/
├── src/          <- código-fonte da lib (.pas)
├── tests/        <- testes DUnitX e mocks
│   └── mocks/
├── samples/      <- exemplos de uso numerados
└── docs/         <- playbook e guias de contribuição
```

Novos arquivos de código-fonte devem ser registrados no `.dpr` e `.dproj` correspondentes imediatamente após a criação.
