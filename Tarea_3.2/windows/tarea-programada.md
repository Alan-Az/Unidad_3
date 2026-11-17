# Ejemplo para Programador de tareas de Windows

Cree dos tareas con la cuenta de servicio de respaldo:

1. Tarea semanal completa, domingo 02:00.
   Programa: powershell.exe
   Argumentos: -NoProfile -File "C:\Scripts\backup.ps1" -SourcePath "D:\Datos" -DestinationPath "E:\Respaldos\Unidad3" -StatePath "E:\Respaldos\Unidad3\.backup-state.json" -Mode Full -SecondaryPath "F:\CopiaSecundaria"
2. Tarea incremental, lunes a sábado 02:00.
   Programa: powershell.exe
   Argumentos: -NoProfile -File "C:\Scripts\backup.ps1" -SourcePath "D:\Datos" -DestinationPath "E:\Respaldos\Unidad3" -StatePath "E:\Respaldos\Unidad3\.backup-state.json" -Mode Incremental -SecondaryPath "F:\CopiaSecundaria"

Pasos en la interfaz:
1. Abra Programador de tareas y seleccione Crear tarea básica o Crear tarea.
2. Asigne un nombre que indique tipo y frecuencia.
3. Configure el desencadenador semanal o diario.
4. Seleccione Iniciar un programa y agregue powershell.exe con los argumentos anteriores.
5. Use la cuenta con permisos mínimos de lectura en el origen y escritura en los destinos.
6. Marque ejecutar solo cuando el usuario haya iniciado sesión si no configuró credenciales de tarea.
7. Ejecute primero manualmente con una carpeta de prueba y confirme backup.log, archivos ZIP y sumas SHA-256.

No seleccione “Ejecutar con los privilegios más altos” salvo que la carpeta de origen realmente lo requiera. No ejecute los ejemplos en esta estación: las rutas son ilustrativas y el destino secundario debe existir.