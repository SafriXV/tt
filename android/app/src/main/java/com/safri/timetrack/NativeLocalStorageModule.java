package com.safri.timetrack;

import android.content.Context;
import android.content.SharedPreferences;
import com.lynx.jsbridge.LynxMethod;
import com.lynx.jsbridge.LynxModule;
import com.lynx.react.bridge.Callback;
import com.lynx.tasm.behavior.LynxContext;

/**
 * The JS side (miso's Native.Module bridge) calls:
 *
 *   NativeLocalStorageModule.setStorageItem(key, value)
 *   NativeLocalStorageModule.getStorageItem(key, callback)
 *
 * SharedPreferences keeps the data on the device, with no network involved.
 */
public final class NativeLocalStorageModule extends LynxModule {

  private static final String PREF_NAME = "timetrack";

  public NativeLocalStorageModule(Context context) {
    super(context);
  }

  public NativeLocalStorageModule(Context context, Object param) {
    super(context, param);
  }

  private Context storageContext() {
    if (mContext instanceof LynxContext) {
      return ((LynxContext) mContext).getContext();
    }
    return mContext;
  }

  private SharedPreferences prefs() {
    return storageContext().getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
  }

  @LynxMethod
  public void setStorageItem(String key, String value) {
    prefs().edit().putString(key, value).apply();
  }

  @LynxMethod
  public void getStorageItem(String key, Callback callback) {
    // A plain String (not null) is the safest value for the JS decoder.
    callback.invoke(prefs().getString(key, ""));
  }
}
