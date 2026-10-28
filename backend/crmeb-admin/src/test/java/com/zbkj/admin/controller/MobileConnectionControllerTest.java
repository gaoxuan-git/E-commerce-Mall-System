package com.zbkj.admin.controller;

import com.zbkj.common.config.CrmebConfig;
import org.junit.Test;
import org.springframework.test.util.ReflectionTestUtils;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import static org.junit.Assert.*;

public class MobileConnectionControllerTest {
    @Test
    public void checksActualImageDirectoryWithoutExposingFilesystemPath() throws Exception {
        Path root = Files.createTempDirectory("crmeb-connection-test");
        try {
            CrmebConfig config = new CrmebConfig();
            config.setImagePath(root.toString());
            MobileConnectionController controller = new MobileConnectionController();
            ReflectionTestUtils.setField(controller, "config", config);
            assertEquals(false, controller.info().getData().get("imageDirectoryReadable"));
            Files.createDirectory(root.resolve("crmebimage"));
            Map<String, Object> data = controller.info().getData();
            assertEquals(true, data.get("imageDirectoryReadable"));
            assertEquals("crmeb-admin", data.get("service"));
            assertEquals(1, data.get("protocolVersion"));
            assertFalse(data.toString().contains(root.toString()));
            config.setImagePath("");
            assertEquals(false, controller.info().getData().get("imageDirectoryReadable"));
        } finally {
            Files.deleteIfExists(root.resolve("crmebimage"));
            Files.deleteIfExists(root);
        }
    }
}
