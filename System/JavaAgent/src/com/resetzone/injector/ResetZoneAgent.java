package com.resetzone.injector;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.lang.instrument.Instrumentation;
import java.lang.reflect.Method;
import java.lang.reflect.Field;

public class ResetZoneAgent {
    private static boolean resetPending = false;
    private static final List<String> filesToDelete = Collections.synchronizedList(new ArrayList<>());
    
    public static void premain(String agentArgs, Instrumentation inst) {
        System.out.println("==========================================");
        System.out.println("[ResetZone] Agent Loaded Successfully (Reflection Mode)");
        System.out.println("==========================================");
        
        // Register shutdown hook
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            if (resetPending) {
                performCleanupAndRestart();
            }
        }, "ResetZone-Cleanup"));
    }

    /**
     * Called from Lua to schedule a reset.
     * @param files A List of string relative file paths to delete.
     */
    public static void scheduleReset(List<String> files) {
        System.out.println("[ResetZone] Reset Scheduled! " + (files != null ? files.size() : 0) + " files to delete.");
        
        if (files != null) {
            filesToDelete.addAll(files);
        }
        
        resetPending = true;

        // Trigger Save and Quit asynchronously to avoid blocking Lua
        new Thread(() -> {
            try {
                System.out.println("[ResetZone] Initiating Save and Quit sequence...");
                
                // Trigger Save via Reflection
                // zombie.GameWindow.save(true)
                Class<?> gameWindow = Class.forName("zombie.GameWindow");
                Method saveMethod = gameWindow.getMethod("save", boolean.class);
                System.out.println("[ResetZone] Calling GameWindow.save(true)...");
                saveMethod.invoke(null, true);
                
                System.out.println("[ResetZone] Save complete. Stopping server...");
                
                // We rely on standard exit.
                System.exit(0);

            } catch (Exception e) {
                System.err.println("[ResetZone] Error during Save/Quit sequence:");
                e.printStackTrace();
                // Force exit if save fails?
                 System.exit(1);
            }
        }, "ResetZone-Trigger").start();
    }

    private static void performCleanupAndRestart() {
        System.out.println("==========================================");
        System.out.println("[ResetZone] SHUTDOWN HOOK: Performing Cleanup");
        System.out.println("==========================================");
        
        try {
            // Reflect into ZomboidFileSystem
            Class<?> zfsClass = Class.forName("zombie.ZomboidFileSystem");
            Field instanceField = zfsClass.getField("instance");
            Object zfsInstance = instanceField.get(null);
            
            // public java.io.File getFileInCurrentSave(java.lang.String);
            Method getFileMethod = zfsClass.getMethod("getFileInCurrentSave", String.class);
            
            for (String relativePath : filesToDelete) {
               try {
                   File targetFile = (File) getFileMethod.invoke(zfsInstance, relativePath);
                   
                   if (targetFile.exists()) {
                       if (targetFile.delete()) {
                           System.out.println("[ResetZone] DELETED: " + relativePath);
                       } else {
                           System.err.println("[ResetZone] FAILED TO DELETE: " + relativePath);
                       }
                   } else {
                       // Silent skip
                   }
               } catch (Exception ex) {
                   System.err.println("[ResetZone] Error resolving/deleting file: " + relativePath + " -> " + ex.getMessage());
               }
            }
            
        } catch (Exception e) {
            System.err.println("[ResetZone] Error accessing ZomboidFileSystem:");
            e.printStackTrace();
        }
        
        System.out.println("[ResetZone] Cleanup Finished.");
        
        // RESTART LOGIC
        // Since we are running as a Service (systemd with Restart=always), 
        // we simply exit. The OS/Service manager will handle the restart.
        System.out.println("[ResetZone] Exiting process. Systemd should restart the service automatically.");
    }
}

