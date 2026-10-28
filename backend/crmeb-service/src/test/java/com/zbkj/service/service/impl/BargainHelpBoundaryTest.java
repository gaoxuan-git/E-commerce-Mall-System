package com.zbkj.service.service.impl;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import com.zbkj.common.exception.CrmebException;
import com.zbkj.common.model.bargain.StoreBargain;
import com.zbkj.common.model.bargain.StoreBargainUser;
import com.zbkj.common.model.bargain.StoreBargainUserHelp;
import com.zbkj.common.model.user.User;
import com.zbkj.common.request.BargainFrontRequest;
import com.zbkj.service.dao.StoreBargainUserHelpDao;
import com.zbkj.service.service.StoreBargainService;
import com.zbkj.service.service.StoreBargainUserService;
import com.zbkj.service.service.UserService;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.MockitoJUnitRunner;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.util.Collections;

import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@RunWith(MockitoJUnitRunner.Silent.class)
public class BargainHelpBoundaryTest {
    @Spy @InjectMocks private StoreBargainUserHelpServiceImpl service;
    @Mock private StoreBargainUserHelpDao dao;
    @Mock private StoreBargainUserService storeBargainUserService;
    @Mock private StoreBargainService storeBargainService;
    @Mock private UserService userService;
    @Mock private TransactionTemplate transactionTemplate;
    private StoreBargainUser activity;
    private BargainFrontRequest request;

    @Before
    public void setUp() {
        MapperBuilderAssistant assistant = new MapperBuilderAssistant(new MybatisConfiguration(), "");
        assistant.setCurrentNamespace("bargain-boundary-test");
        TableInfoHelper.initTableInfo(assistant, StoreBargainUserHelp.class);
        TableInfoHelper.initTableInfo(assistant, StoreBargainUser.class);
        TableInfoHelper.initTableInfo(assistant, StoreBargain.class);
        StoreBargain bargain = new StoreBargain().setId(10).setIsDel(false).setStatus(true)
                .setQuota(10).setStock(10).setStartTime(System.currentTimeMillis() - 10000)
                .setStopTime(System.currentTimeMillis() + 600000).setPeopleNum(5)
                .setBargainNum(1).setShare(0);
        activity = new StoreBargainUser().setId(20).setBargainId(10).setUid(1)
                .setIsDel(false).setStatus(1).setPrice(new BigDecimal("10.00"))
                .setBargainPrice(new BigDecimal("100.00")).setBargainPriceMin(new BigDecimal("50.00"));
        request = new BargainFrontRequest().setBargainId(10).setBargainUserId(20).setBargainUserUid(1);
        when(userService.getInfoException()).thenReturn(new User().setUid(2));
        when(storeBargainService.getById(10)).thenReturn(bargain);
        when(storeBargainUserService.getById(20)).thenReturn(activity);
        when(storeBargainUserService.getListByBargainIdAndUid(10, 2)).thenReturn(Collections.emptyList());
        when(storeBargainUserService.update(any())).thenReturn(true);
        when(storeBargainService.update(any())).thenReturn(true);
        when(transactionTemplate.execute(any())).thenAnswer(invocation ->
                ((TransactionCallback<?>) invocation.getArgument(0)).doInTransaction(null));
        doReturn(true).when(service).save(any(StoreBargainUserHelp.class));
    }

    private void rejected(String message) {
        try {
            service.help(request);
            fail("Expected rejection: " + message);
        } catch (CrmebException ex) {
            assertTrue(ex.getMessage(), ex.getMessage().contains(message));
        }
    }

    @Test public void duplicateFriendIsRejectedBeforeAnyWrite() {
        when(dao.selectCount(any())).thenReturn(1);
        when(dao.selectOne(any())).thenReturn(new StoreBargainUserHelp());
        rejected("已经砍过");
        verifyNoInteractions(transactionTemplate);
    }

    @Test public void differentActivityCannotBeUsedForHelp() {
        activity.setBargainId(11);
        rejected("不匹配");
        verifyNoInteractions(transactionTemplate);
    }

    @Test public void deletedParticipationCannotBeHelped() {
        activity.setIsDel(true);
        rejected("已取消");
        verifyNoInteractions(transactionTemplate);
    }

    @Test public void expiredParticipationCannotBeHelped() {
        activity.setStatus(2);
        rejected("已过期");
        verifyNoInteractions(transactionTemplate);
    }

    @Test public void friendLimitAppliesWithoutAnyOwnParticipation() {
        when(dao.selectCount(any())).thenReturn(0, 1);
        rejected("上限");
        verifyNoInteractions(transactionTemplate);
    }

    @Test public void failedOptimisticPriceUpdateDoesNotSaveHelp() {
        when(storeBargainUserService.update(any())).thenReturn(false);
        rejected("砍价失败");
        verify(service, never()).save(any(StoreBargainUserHelp.class));
    }

    @Test public void failedHelpInsertFailsTransaction() {
        doReturn(false).when(service).save(any(StoreBargainUserHelp.class));
        rejected("砍价失败");
        verify(storeBargainService, never()).update(any());
    }

    @Test public void failedShareUpdateFailsTransaction() {
        when(storeBargainService.update(any())).thenReturn(false);
        rejected("砍价失败");
    }

    @Test public void normalFriendHelpStoresExactlyOnePositiveAmount() {
        BigDecimal amount = (BigDecimal) service.help(request).get("bargainPrice");
        assertTrue(amount.signum() > 0);
        assertTrue(amount.compareTo(new BigDecimal("40.00")) <= 0);
        verify(service).save(any(StoreBargainUserHelp.class));
    }

    @Test public void legacyDuplicateRowsStillReportHelped() {
        when(dao.selectCount(any())).thenReturn(2);
        assertTrue(service.getIsHelp(20, 2));
        verify(dao, never()).selectOne(any());
    }

    @Test public void detailRejectsRecordFromAnotherActivity() {
        StoreBargainUserServiceImpl readService = spy(new StoreBargainUserServiceImpl());
        ReflectionTestUtils.setField(readService, "userService", userService);
        ReflectionTestUtils.setField(readService, "storeBargainService", storeBargainService);
        doReturn(activity.setBargainId(11)).when(readService).getById(20);
        try {
            readService.getBargainUserInfo(request);
            fail("Expected activity mismatch rejection");
        } catch (CrmebException ex) {
            assertTrue(ex.getMessage().contains("不匹配"));
        }
    }
}
