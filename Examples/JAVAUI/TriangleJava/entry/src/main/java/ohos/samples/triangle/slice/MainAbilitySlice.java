package ohos.samples.triangle.slice;

import ohos.agp.components.DirectionalLayout;
import ohos.agp.components.surfaceprovider.SurfaceProvider;
import ohos.samples.triangle.ResourceTable;
import ohos.aafwk.ability.AbilitySlice;
import ohos.aafwk.content.Intent;

public class MainAbilitySlice extends AbilitySlice {

    @Override
    public void onStart(Intent intent) {
        super.onStart(intent);
        super.setUIContent(ResourceTable.Layout_ability_main);
        DirectionalLayout layout = (DirectionalLayout) findComponentById(ResourceTable.Id_surface_layout);
        Triangle triangle = new Triangle(this);
        SurfaceProvider provider = triangle.initSliceLayout();

        layout.addComponent(provider);
        triangle.startDraw();
    }

    @Override
    public void onActive() {
        super.onActive();
    }

    @Override
    public void onForeground(Intent intent) {
        super.onForeground(intent);
    }
}
