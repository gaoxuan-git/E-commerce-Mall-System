import { mount } from '@vue/test-utils';
import SmsConfig from '@/views/sms/smsConfig/config.vue';

describe('SmsConfig development mode', () => {
  it('shows the local service state without rendering an external iframe', async () => {
    const wrapper = mount(SmsConfig, {
      global: {
        mocks: {
          $selfUtil: { getTableHeight: () => 720 },
        },
        stubs: {
          'el-result': {
            props: ['title'],
            template: '<div data-test="local-service">{{ title }}</div>',
          },
          'el-empty': true,
        },
      },
    });

    await wrapper.vm.$nextTick();

    expect(wrapper.get('[data-test="local-service"]').text()).toBe('本地模拟服务运行中');
    expect(wrapper.find('iframe').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('一号通');
  });
});
