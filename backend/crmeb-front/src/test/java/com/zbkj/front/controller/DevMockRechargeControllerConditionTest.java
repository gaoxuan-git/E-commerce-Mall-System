package com.zbkj.front.controller;

import com.zbkj.front.service.DevMockRechargeService;
import org.junit.Assert;
import org.junit.Test;
import org.springframework.boot.test.util.TestPropertyValues;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

import static org.mockito.Mockito.mock;

public class DevMockRechargeControllerConditionTest {

    private static final String ENABLED_PROPERTY =
            "crmeb.payment.dev-mock-recharge.enabled=";

    @Test
    public void controllerIsRegisteredWhenDevProfileAndSwitchAreEnabled() {
        try (AnnotationConfigApplicationContext context = loadContext("dev", true)) {
            Assert.assertEquals(1, context.getBeansOfType(
                    DevMockRechargeController.class).size());
        }
    }

    @Test
    public void controllerIsNotRegisteredWhenSwitchIsDisabled() {
        try (AnnotationConfigApplicationContext context = loadContext("dev", false)) {
            Assert.assertTrue(context.getBeansOfType(
                    DevMockRechargeController.class).isEmpty());
        }
    }

    @Test
    public void controllerIsNotRegisteredOutsideDevProfile() {
        try (AnnotationConfigApplicationContext context = loadContext("prod", true)) {
            Assert.assertTrue(context.getBeansOfType(
                    DevMockRechargeController.class).isEmpty());
        }
    }

    private AnnotationConfigApplicationContext loadContext(
            String profile, boolean enabled) {
        AnnotationConfigApplicationContext context =
                new AnnotationConfigApplicationContext();
        context.getEnvironment().setActiveProfiles(profile);
        TestPropertyValues.of(ENABLED_PROPERTY + enabled).applyTo(context);
        context.getBeanFactory().registerSingleton(
                "devMockRechargeService", mock(DevMockRechargeService.class));
        context.register(DevMockRechargeController.class);
        context.refresh();
        return context;
    }
}
