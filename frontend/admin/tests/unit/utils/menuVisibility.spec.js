import { describe, expect, it } from 'vitest';
import { filterVendorMenus } from '@/utils/menuVisibility';

describe('filterVendorMenus', () => {
  it('removes vendor entries recursively while retaining business siblings', () => {
    const input = [
      {
        component: '/operation',
        childList: [
          { component: '/operation/setting', childList: [] },
          { component: '/operation/onePassConfig', childList: [] },
          { component: '/operation/systemSms/pay', childList: [] },
        ],
      },
      {
        component: '/appSetting',
        childList: [
          { component: '/appSetting/publicRoutine/download', childList: [] },
          { component: '/appSetting/publicRoutine/deliveryManagement', childList: [] },
        ],
      },
    ];

    const result = filterVendorMenus(input);

    expect(result[0].childList.map((item) => item.component)).toEqual(['/operation/setting']);
    expect(result[1].childList.map((item) => item.component)).toEqual([
      '/appSetting/publicRoutine/deliveryManagement',
    ]);
    expect(input[0].childList).toHaveLength(3);
  });

  it('supports menu trees already converted to children', () => {
    const result = filterVendorMenus([
      {
        component: '/operation',
        children: [
          { component: '/operation/onePassConfig', children: [] },
          { component: '/operation/logistics/freightSet', children: [] },
        ],
      },
    ]);

    expect(result[0].children.map((item) => item.component)).toEqual([
      '/operation/logistics/freightSet',
    ]);
  });

  it('removes parents emptied by vendor filtering while keeping real leaves', () => {
    const result = filterVendorMenus([
      {
        component: '/appSetting',
        childList: [
          {
            component: '/appSetting/publicRoutine',
            childList: [
              {
                component: '/appSetting/publicRoutine/download',
                childList: [],
              },
            ],
          },
          {
            component: '/appSetting/publicAccount/wxMenus',
            childList: [],
          },
        ],
      },
    ]);

    expect(result[0].childList.map((item) => item.component)).toEqual([
      '/appSetting/publicAccount/wxMenus',
    ]);
  });
});
