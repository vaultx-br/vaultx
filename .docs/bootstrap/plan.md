# Reset e teste 003

## Estado

Reset confirmado em 2026-07-30: `config.age`, `config.env` aberto e artefatos dos testes 001/002 foram removidos. O PAT local `.source/_secrets/.git.env` não faz parte da configuração e permanece ignorado.

## Plano

1. Gerar um Genesis isolado em `.source/_test/003/genesis.age` e guardar o QR fora do repositório.
2. Restaurar suas chaves apenas em `/dev/shm`, criar um `config.env` temporário a partir de `example.config.env` e criptografá-lo como `.source/_test/003/config.age`.
3. Executar o bootstrap com `--genesis-file` e `--config-file` apontando para o teste 003; validar Docker Compose e containers.
4. Limpar o ambiente de teste.
5. Só depois gerar o Genesis e `config.age` de produção em `.source/_secrets/`, versionar o `.age` criptografado e testar o wizard remoto.

Nenhum arquivo aberto, Genesis ou chave privada é versionado.

## Resultado do teste 003

O bootstrap com Genesis e configuração isolados foi validado localmente: `age.key` e `config.env` runtime foram criados com permissão `600`; Vaultwarden ficou saudável; ntfy e Backup SVC ficaram em execução; nenhuma porta foi publicada no host. O bootstrap passou a instalar/iniciar `openssh-server` e normalizar caminhos relativos dos arquivos fornecidos. O Tunnel não conectou porque o token de teste é inválido. O Vaultwarden alertou que o `ADMIN_TOKEN` do teste está em texto simples; antes da produção ele deve ser substituído por um hash Argon2 PHC.
