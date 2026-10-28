package com.zbkj.common.utils;

import org.junit.Assert;
import org.junit.Test;

public class CrmebUtilPasswordCompatibilityTest {

    @Test
    public void encryptionMatchesExistingDemoPassword() {
        Assert.assertEquals("b34Evwm5B/w=",
                CrmebUtil.encryptPassword("123456", "13800800001"));
    }

    @Test
    public void decryptsPasswordStoredBeforeJdkMigration() throws Exception {
        Assert.assertEquals("123456",
                CrmebUtil.decryptPassowrd("b34Evwm5B/w=", "13800800001"));
    }
}
