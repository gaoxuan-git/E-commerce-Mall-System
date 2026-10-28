package com.zbkj.front.controller;

import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.user.User;
import com.zbkj.service.service.StoreCartService;
import com.zbkj.service.service.UserService;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;

import java.util.Collections;

import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@RunWith(MockitoJUnitRunner.class)
public class CartControllerAuthorizationTest {

    private static final Integer USER_ID = 21;
    private static final Integer OTHER_CART_ID = 600002;

    @InjectMocks
    private CartController cartController;

    @Mock
    private StoreCartService storeCartService;

    @Mock
    private UserService userService;

    @Before
    public void setUp() {
        when(userService.getInfoException()).thenReturn(new User().setUid(USER_ID));
        when(storeCartService.getByIdAndUid(OTHER_CART_ID.longValue(), USER_ID)).thenReturn(null);
    }

    @Test
    public void updateRejectsAnotherUsersCart() {
        assertCartMissing(() -> cartController.update(OTHER_CART_ID, 2));
        verify(storeCartService, never()).updateCartNum(OTHER_CART_ID, 2);
    }

    @Test
    public void deleteRejectsAnotherUsersCart() {
        assertCartMissing(() -> cartController.delete(Collections.singletonList(OTHER_CART_ID.longValue())));
        verify(storeCartService, never()).deleteCartByIds(Collections.singletonList(OTHER_CART_ID.longValue()));
    }

    private void assertCartMissing(Runnable action) {
        try {
            action.run();
            Assert.fail("Expected ownership check to reject cart access");
        } catch (CrmebException exception) {
            Assert.assertEquals("当前购物车不存在", exception.getMessage());
        }
    }
}
