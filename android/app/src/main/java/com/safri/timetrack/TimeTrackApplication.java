package com.safri.timetrack;

import android.app.Application;
import com.facebook.drawee.backends.pipeline.Fresco;
import com.lynx.service.http.LynxHttpService;
import com.lynx.service.image.LynxImageService;
import com.lynx.service.log.LynxLogService;
import com.lynx.tasm.LynxEnv;
import com.lynx.tasm.service.LynxServiceCenter;

/** One-time Lynx setup, run when the app process starts. */
public class TimeTrackApplication extends Application {

  @Override
  public void onCreate() {
    super.onCreate();
    Fresco.initialize(this);
    LynxServiceCenter.inst().registerService(LynxImageService.getInstance());
    LynxServiceCenter.inst().registerService(LynxLogService.INSTANCE);
    LynxServiceCenter.inst().registerService(LynxHttpService.INSTANCE);
    LynxEnv.inst().init(this, null, null, null);
    LynxEnv.inst().registerModule(
        "NativeLocalStorageModule", NativeLocalStorageModule.class);
  }
}
