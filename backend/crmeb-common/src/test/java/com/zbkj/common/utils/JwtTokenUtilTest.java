package com.zbkj.common.utils;

import com.zbkj.common.constants.Constants;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.SignatureException;
import org.junit.Assert;
import org.junit.Test;

import java.util.Collections;

public class JwtTokenUtilTest {

    @Test
    public void signsAndParsesFrontAndAdminTokensOnCurrentRuntime() {
        for (String type : new String[]{Constants.JWT_TOKEN_TYPE_FRONT, Constants.JWT_TOKEN_TYPE_ADMIN}) {
            String token = JwtTokenUtil.createToken("42", type,
                    Collections.singletonMap("uid", 42), 5);
            Claims claims = JwtTokenUtil.parseToken(token);

            Assert.assertEquals("42", claims.getSubject());
            Assert.assertEquals(42, claims.get("uid"));
            Assert.assertTrue(JwtTokenUtil.isTokenType(claims, type));
            Assert.assertNotNull(claims.getIssuedAt());
            Assert.assertTrue(claims.getExpiration().after(claims.getIssuedAt()));
            Assert.assertEquals(token, JwtTokenUtil.resolveBearerToken("Bearer " + token));
        }
    }

    @Test(expected = SignatureException.class)
    public void rejectsModifiedSignature() {
        String token = JwtTokenUtil.createToken("42", Constants.JWT_TOKEN_TYPE_FRONT,
                Collections.emptyMap(), 5);
        int signatureStart = token.lastIndexOf('.') + 1;
        char replacement = token.charAt(signatureStart) == 'A' ? 'B' : 'A';
        String modified = token.substring(0, signatureStart) + replacement
                + token.substring(signatureStart + 1);

        JwtTokenUtil.parseToken(modified);
    }
}
