# Servidor de salas Dungeon

A simulação de PvP é **Godot/GDScript**, compartilhada com o treino. Cada processo guarda as salas em memória; um reinício encerra essas salas. Dois clientes enviam intenções de jogada e recebem snapshots a 10 Hz. O servidor escolhe o lado de cada conexão, valida energia, posição, carta e cooldown, simula combate e decide o resultado. Clientes não enviam estados nem dano.

## Executar

Na raiz do repositório, com Godot 4.4.1:

```sh
godot --headless --path godot --script "$PWD/server/rooms.gd" -- --port=9080
```

O servidor imprime `DUNGEON_ROOMS_READY port=9080`. Em um cliente servido por HTTP local, abra Salas e informe `ws://127.0.0.1:9080`. Crie a sala num navegador e entre com o código de seis caracteres em outro. Cada conexão controla somente seu invocador. Sair ou perder a conexão encerra a sala e concede vitória ao jogador restante; não há retomada da mesma partida.

```sh
npm install --prefix /tmp/dungeon-network ws
NODE_PATH=/tmp/dungeon-network/node_modules node tests/mutable_rooms.cjs
```

## Publicar para jogadores na internet

O GitHub Pages hospeda apenas o cliente e **não executa este servidor**. Não existe um backend público pré-configurado no repositório. Publique o container em um host com suporte a WebSockets persistentes, um processo e uma instância, e termine TLS num proxy reverso. Na raiz:

```sh
docker build -f server/Dockerfile -t dungeon-rooms .
docker run --restart unless-stopped -p 127.0.0.1:9080:9080 dungeon-rooms
```

Exemplo de Caddyfile (troque pelo seu domínio, com DNS configurado):

```caddy
salas.seu-dominio.com {
    reverse_proxy 127.0.0.1:9080
}
```

Informe `wss://salas.seu-dominio.com` em Salas. Também é possível compartilhar o cliente com `?server=wss%3A%2F%2Fsalas.seu-dominio.com`; o jogador ainda escolhe criar/entrar. Uma página HTTPS precisa de WSS para evitar bloqueio de conteúdo misto. Não coloque credenciais no endereço.

Há limite de 128 conexões, 64 salas, mensagens de 2 KiB, orçamento de comandos por conexão, timeout de handshake, heartbeat e expiração de sala. O código é aleatório e a terceira conexão não entra em uma sala cheia. Isto permite duelos privados; não fornece contas, matchmaking, ranking global, temporadas de servidor nem proteção de recompensas locais contra edição. Antes de operar ligas competitivas, essas funções precisam de armazenamento e identidade de servidor.
