package com.zbkj.common.request;

import org.junit.Assert;
import org.junit.Test;

import javax.validation.Validation;
import javax.validation.Validator;

public class RegisterRequestTest {

    private final Validator validator =
            Validation.buildDefaultValidatorFactory().getValidator();

    @Test
    public void acceptsValidRegistration() {
        Assert.assertTrue(validator.validate(validRequest()).isEmpty());
    }

    @Test
    public void rejectsInvalidPhoneCodeAndPassword() {
        RegisterRequest request = validRequest()
                .setPhone("123")
                .setCaptcha("12")
                .setPassword("123456");

        Assert.assertEquals(3, validator.validate(request).size());
    }

    private RegisterRequest validRequest() {
        return new RegisterRequest()
                .setPhone("13900000001")
                .setCaptcha("123456")
                .setPassword("Pass_123")
                .setSpreadPid(0);
    }
}
