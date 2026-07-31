# Release e rollback

## Princípio

Uma release de produção associa uma versão do código a um snapshot Restic que foi restaurado e validado com essa versão.

## Pipeline de promoção

1. **Preparar**
   - árvore Git limpa;
   - secrets finais cifrados;
   - credenciais rotacionadas e com menor privilégio;
   - testes locais aprovados.
2. **Instalar em VM limpa**
   - usar o commit candidato;
   - validar host, runtime, quatro serviços e Tunnel.
3. **Popular e congelar**
   - desabilitar novos cadastros após preparar a conta;
   - incluir um anexo real para prova;
   - evitar mutações durante o snapshot candidato.
4. **Criar o restore-point**

```bash
sudo vacum backup
sudo vacum status
sudo vacum check
sudo vacum doctor
```

5. **Restaurar destrutivamente em ambiente descartável**
   - usar nó e snapshot explícitos;
   - validar SQLite, login, itens, pastas, anexo, chave RSA, domínio e reboot;
   - registrar RTO e RPO observados.
6. **Promover**
   - criar tag anotada com snapshot e resultados;
   - publicar release sobre a tag;
   - não mover ou reutilizar tags de produção.

Exemplo sem dados reais:

```bash
git tag -a production-AAAA-MM-DD \
  -m 'restore=NODE:SNAPSHOT; check=PASS; doctor=PASS; recovery=PASS; RTO=Ns; RPO=Ns'
git push origin production-AAAA-MM-DD
```

## Critério GO

Todos obrigatórios:

- testes e árvore Git aprovados;
- nenhuma credencial aberta rastreada;
- instalação limpa concluída;
- quatro serviços e Tunnel saudáveis;
- backup real consultável;
- restore destrutivo aprovado;
- banco, conta, itens, anexo e chaves recuperados;
- reboot, `check` e `doctor` aprovados;
- RTO/RPO aceitos;
- tag associada ao snapshot comprovado.

Qualquer falha mantém **NO-GO**.

## Bloqueios de promoção

Não crie tag de produção enquanto existir qualquer um destes estados:

- credencial sem rotação ou privilégio revisado;
- par Genesis/`secrets.age` não provado por instalação limpa;
- Tunnel, ntfy ou destino Restic não validados no ambiente final;
- snapshot candidato não restaurado;
- volume recuperado sem validação de login/anexo;
- reboot sem rematerialização do runtime;
- árvore Git suja, `check` ou `doctor` com falha;
- código distribuído diferente do commit que foi testado.

## Rollback

- Código: checkout da tag aprovada anterior.
- Configuração: materialize o `secrets.age` daquela tag usando o Genesis correspondente.
- Dados: restaure exatamente o snapshot registrado na release.
- Validação: repita SQLite, login, anexo, domínio, reboot, `check` e `doctor`.

Nunca combine silenciosamente código, Genesis, configuração e snapshot de releases diferentes.

## Limitação atual da distribuição

O loader remoto ainda baixa `master` sem checksum. Até haver release fixada no loader, faça promoção e rollback por clone/tag explicitamente controlados e trate `curl | sh` como conveniência não reprodutível.

## Registro mínimo da release

Registre sem incluir credenciais:

- tag e commit;
- versões das imagens;
- nome do destino e ID do snapshot;
- horário do snapshot;
- resultado de backup, restore, reboot, `check` e `doctor`;
- RTO e RPO observados;
- limitações conhecidas, incluindo Sends fora do backup.
