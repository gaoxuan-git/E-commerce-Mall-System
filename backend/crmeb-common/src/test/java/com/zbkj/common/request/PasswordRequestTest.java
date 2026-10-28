package com.zbkj.common.request;

import org.junit.Assert;
import org.junit.Test;

import javax.validation.Validation;
import javax.validation.Validator;

public class PasswordRequestTest {
    private final Validator validator = Validation.buildDefaultValidatorFactory().getValidator();

    @Test
    public void acceptsValidPasswordReset() {
        Assert.assertTrue(validator.validate(validRequest()).isEmpty());
    }

    @Test
    public void requiresPasswordAndVerificationCode() {
        Assert.assertEquals(2, validator.validate(validRequest()
                .setPassword(null).setValidateCode(null)).size());
    }

    @Test
    public void rejectsBlankAndMalformedFields() {
        Assert.assertFalse(validator.validate(validRequest().setPassword("")).isEmpty());
        Assert.assertFalse(validator.validate(validRequest().setValidateCode("")).isEmpty());
        Assert.assertFalse(validator.validate(validRequest().setPassword("123456")).isEmpty());
        Assert.assertFalse(validator.validate(validRequest().setValidateCode("12")).isEmpty());
    }

    private PasswordRequest validRequest() {
        return new PasswordRequest().setPhone("13900000001")
                .setPassword("Pass_123").setValidateCode("123456");
    }
}
