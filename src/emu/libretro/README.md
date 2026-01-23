# Libretro Multi-Platform Support

Esta estrutura permite que o emulador Libretro funcione em múltiplas plataformas (Windows, Android, Linux, macOS).

## Estrutura de Arquivos

```
src/emu/libretro/
├── ILibraryLoader.cs              # Interface comum para todos os loaders
├── LibraryLoaderFactory.cs        # Factory que escolhe o loader correto
├── LibretroNative.cs              # API principal do Libretro (multiplataforma)
├── LibretroPlayer.cs              # Player do emulador
├── windows/
│   └── WindowsLibraryLoader.cs    # Implementação para Windows (kernel32.dll)
└── android/
    └── AndroidLibraryLoader.cs    # Implementação para Android (libdl.so)
```

## Como Funciona

1. **LibraryLoaderFactory** detecta automaticamente a plataforma em execução
2. Cria o **ILibraryLoader** apropriado:
   - Windows: usa `kernel32.dll` (LoadLibrary, GetProcAddress, FreeLibrary)
   - Android/Linux/macOS: usa `libdl.so` (dlopen, dlsym, dlclose)
3. **LibretroNative** usa o loader para carregar cores dinamicamente

## Suporte a Plataformas

### Windows
- Extensão de biblioteca: `.dll`
- API: kernel32.dll (LoadLibrary)

### Android
- Extensão de biblioteca: `.so`
- API: libdl.so (dlopen)
- Arquitetura suportada: armeabi-v7a (antigos), arm64-v8a (novos)

### Linux (Untested)
- Extensão de biblioteca: `.so`
- API: libdl.so (dlopen)

### macOS
- Extensão de biblioteca: `.dylib` ou `.so`
- API: libdl.so (dlopen)

## Uso no Android

Para usar cores Libretro no Android:

1. Importe o core `.so` compilado para Android (ex: `mgba_libretro_android.so`)
2. O sistema detectará automaticamente que está no Android
3. Usará `dlopen` em vez de `LoadLibrary`
4. O jogo funcionará normalmente

## Notas Importantes

- **Arquitetura ARM**: Certifique-se de que o core `.so` foi compilado para a arquitetura correta (armeabi-v7a ou arm64-v8a)
- **Permissões**: No Android, pode ser necessário permissões de armazenamento
- **Paths**: Use `user://` ou caminhos relativos para compatibilidade multiplataforma
