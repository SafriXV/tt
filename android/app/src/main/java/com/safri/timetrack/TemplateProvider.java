package com.safri.timetrack;

import android.content.Context;
import com.lynx.tasm.provider.AbsTemplateProvider;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

/** Loads the .lynx.bundle from the app's assets. The app is fully offline. */
public class TemplateProvider extends AbsTemplateProvider {

  private final Context context;

  public TemplateProvider(Context context) {
    this.context = context.getApplicationContext();
  }

  @Override
  public void loadTemplate(String uri, Callback callback) {
    new Thread(
            () -> {
              try (InputStream in = context.getAssets().open(uri);
                  ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                byte[] buffer = new byte[4096];
                int length;
                while ((length = in.read(buffer)) != -1) {
                  out.write(buffer, 0, length);
                }
                callback.onSuccess(out.toByteArray());
              } catch (IOException e) {
                callback.onFailed(e.getMessage());
              }
            })
        .start();
  }
}
