using Godot;
using System;

public static class LibraryLoaderFactory
{
	private static ILibraryLoader _instance;

	public static ILibraryLoader GetLoader()
	{
		if (_instance != null)
			return _instance;

		string osName = OS.GetName();
		
		GD.Print($"[LibraryLoaderFactory] Detected OS: {osName}");

		switch (osName)
		{
			case "Windows":
				_instance = new WindowsLibraryLoader();
				GD.Print("[LibraryLoaderFactory] Using Windows library loader");
				break;

			case "Android":
				_instance = new AndroidLibraryLoader();
				GD.Print("[LibraryLoaderFactory] Using Android library loader");
				break;

			case "Linux":
			case "FreeBSD":
			case "NetBSD":
			case "OpenBSD":
			case "BSD":
				_instance = new AndroidLibraryLoader();
				GD.Print("[LibraryLoaderFactory] Using Linux library loader (dlopen)");
				break;

			case "macOS":
				_instance = new AndroidLibraryLoader();
				GD.Print("[LibraryLoaderFactory] Using macOS library loader (dlopen)");
				break;

			default:
				GD.PrintErr($"[LibraryLoaderFactory] Unsupported platform: {osName}");
				_instance = new WindowsLibraryLoader();
				break;
		}

		return _instance;
	}
}
