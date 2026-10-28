package com.zbkj.common.config;

import org.springframework.beans.factory.config.BeanPostProcessor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.ReflectionUtils;
import org.springframework.web.servlet.mvc.method.RequestMappingInfoHandlerMapping;
import springfox.documentation.spring.web.plugins.WebMvcRequestHandlerProvider;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

@Configuration
public class SpringfoxCompatibilityConfig {

    @Bean
    public static BeanPostProcessor springfoxHandlerMappingsCompatibility() {
        return new BeanPostProcessor() {
            @Override
            @SuppressWarnings("unchecked")
            public Object postProcessBeforeInitialization(Object bean, String beanName) {
                if (bean instanceof WebMvcRequestHandlerProvider) {
                    Field field = Objects.requireNonNull(ReflectionUtils.findField(
                            WebMvcRequestHandlerProvider.class, "handlerMappings"));
                    ReflectionUtils.makeAccessible(field);
                    List<RequestMappingInfoHandlerMapping> mappings =
                            (List<RequestMappingInfoHandlerMapping>) ReflectionUtils.getField(field, bean);
                    // 只调整 Swagger 的扫描列表；Actuator 等实际请求映射保持不变。
                    List<RequestMappingInfoHandlerMapping> compatibleMappings =
                            new ArrayList<>(Objects.requireNonNull(mappings));
                    compatibleMappings.removeIf(mapping -> mapping.getPatternParser() != null);
                    ReflectionUtils.setField(field, bean, compatibleMappings);
                }
                return bean;
            }
        };
    }
}
