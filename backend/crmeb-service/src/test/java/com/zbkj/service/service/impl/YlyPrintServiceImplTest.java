package com.zbkj.service.service.impl;

import com.zbkj.common.exception.CrmebException;
import com.zbkj.service.service.StoreOrderInfoService;
import com.zbkj.service.service.StoreOrderService;
import com.zbkj.service.service.SystemConfigService;
import com.zbkj.service.util.YlyUtil;
import org.junit.Assert;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class YlyPrintServiceImplTest {

    @InjectMocks
    private YlyPrintServiceImpl ylyPrintService;

    @Mock
    private StoreOrderService storeOrderService;

    @Mock
    private StoreOrderInfoService storeOrderInfoService;

    @Mock
    private SystemConfigService systemConfigService;

    @Mock
    private YlyUtil ylyUtil;

    @Test
    public void automaticPrintSkipsWhenPrinterIsDisabled() {
        when(ylyUtil.checkYlyPrintStatus()).thenReturn(true);

        ylyPrintService.YlyPrint("order-1", true);

        verify(storeOrderService, never()).getByOderId(anyString());
    }

    @Test
    public void manualPrintReportsDisabledPrinter() {
        when(ylyUtil.checkYlyPrintStatus()).thenReturn(true);

        try {
            ylyPrintService.YlyPrint("order-1", false);
            Assert.fail("Expected disabled printer error");
        } catch (CrmebException exception) {
            Assert.assertEquals("易联云 未开启打印", exception.getMessage());
        }
    }
}
