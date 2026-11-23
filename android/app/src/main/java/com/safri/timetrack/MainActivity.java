package com.safri.timetrack;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import com.lynx.tasm.LynxView;
import com.lynx.tasm.LynxViewBuilder;
import com.lynx.tasm.ThreadStrategyForRendering;
import com.lynx.xelement.XElementBehaviors;

/** Hosts the Haskell/miso Lynx bundle. */
public class MainActivity extends Activity {

  private static final String TEMPLATE_URL = "main.lynx.bundle";

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    LynxViewBuilder builder = new LynxViewBuilder();
    builder.addBehaviors(new XElementBehaviors().create());
    builder.setTemplateProvider(new TemplateProvider(this));
    builder.setThreadStrategyForRendering(ThreadStrategyForRendering.ALL_ON_UI);

    LynxView lynxView = builder.build(this);
    lynxView.setBackgroundColor(Color.WHITE);
    setContentView(lynxView);
    lynxView.renderTemplateUrl(TEMPLATE_URL, "");
  }
}
