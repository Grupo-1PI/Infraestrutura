# Padrão de Commits

Este projeto utiliza o padrão **Conventional Commits**
Todos os commits precisam seguir este formato:

```
Escopo: descrição curta
```

---

## Estrutura

```
Exemplos
feat: cria sistema de login
fix: corrige erro de validação
docs: adiciona instruções do projeto
```

---

## Tipos De Commit's

| Tipo     | Uso                                   |
| -------- | ------------------------------------- |
| feat     | Nova funcionalidade                   |
| fix      | Correção de bug                       |
| refactor | Refatoração sem alterar comportamento |
| perf     | Melhoria de performance               |
| style    | Formatação / UI / indentação          |
| docs     | Documentação                          |
| test     | Testes                                |
| chore    | Configuração / dependências           |
| ci       | Integração contínua                   |
| build    | Build ou ferramentas                  |
| hotfix   | Correção urgente em produção          |

---

## Escopos Comuns

| Escopo      | Quando usar          |
| ----------- | -------------------- |
| auth        | Autenticação         |
| api         | Backend / endpoints  |
| db          | Banco de dados       |
| ui          | Interface            |
| infra       | Infraestrutura       |
| docs        | Documentação         |
| config      | Configurações        |
| integration | Integrações externas |

---

## Exemplos CORRETOS

```
feat: adiciona dashboard inicial
fix: corrige retorno 500 no cadastro
refactor: melhora modelagem das tabelas
docs: adiciona diagrama de arquitetura
```

---

## Fluxo de Branch

```
main → produção
homologation → integração
development → desenvolvimento
```
