# Movimento da arena no export Web

Medição com Godot 4.4.1 e o roteiro `tests/tavern_performance.cjs`. Cada versão teve uma execução de 12 segundos em combate após a primeira invocação, com semente 69, viewport de 390 × 844, Chromium headless, SwiftShader e limitação de CPU de 4×. O roteiro mede os intervalos entre callbacks de animação do navegador.

| Versão | FPS médio | Menor FPS em janela de 1 s | Intervalo p95 |
| --- | ---: | ---: | ---: |
| Antes (2cda03b) | 11,47 | 8,31 | 150,0 ms |
| Com os efeitos desta etapa | 12,02 | 8,71 | 116,7 ms |

Uma amostra por versão descreve estas execuções. A validação da meta de 60 fps ainda requer uma medição em Safari num iPhone físico, com identificação do modelo e da versão do iOS.
