# Espresso3G: начало порта LineageOS 20 / Android 13

Статус: **подготовка исходников, ROM не собран и не проверен на устройстве**.

## Изменения

- Основа espresso3g из lineage-15.1: `de99e8c84a33b6ced461f9461c534c1478b37b69`.
- Продукт зарегистрирован через COMMON_LUNCH_CHOICES, файл продукта переименован
  в lineage_espresso3g.mk; старый vendorsetup.sh удалён.
- Подключён system.prop, выбран GCC для ядра, отключён PSI-путь LMKD.
- TARGET_HAS_MEMFD_BACKPORT=false: в выбранном ядре memfd_create не найден.
- В local_manifest.xml закреплены SHA 28 внешних проектов: OMAP
  device/hardware/kernel/vendor и системные форки rINanDO для Android 13.
- Патч общей конфигурации переводит ошибочную запись recovery-файла из
  PRODUCT_PACKAGES в PRODUCT_COPY_FILES.

Это новая, непроверенная композиция, а не manifest опубликованной сборки S2.
Exynos device/hardware/kernel не используются. Совместимость выбранных SHA
форков rINanDO между собой и с OMAP ещё предстоит проверить. Полный Android
checkout пока не зафиксирован: базовый manifest содержит плавающие ветки
LineageOS. После sync сохранить `repo manifest -r` для точного воспроизведения.

lineage.dependencies намеренно пуст: состав задаёт local manifest, чтобы
roomservice не скачивал старые зависимости из неправильного namespace.

## Что реально проверено, 2026-11-04

- OMAP-ядро 3.4.112, коммит `4f4a4b2427c5b09ec0442c0578957322ff4c7ca6`,
  собрано с espresso_defconfig и GCC 4.9 из закреплённого форка rINanDO.
- Получен arch/arm/boot/zImage. Исходники ядра не менялись. Это контрольная
  сборка существующего ядра, не проверка Android 13 и не готовый boot.img.
- Android runner завершился с кодом 2 **до lunch и компиляции Android**:
  отсутствует build/envsetup.sh. В среде около 58 GiB свободного места;
  полный sync Android не выполнялся.
- Проверены XML/JSON, уникальность путей, SHA зависимостей, linkfile для
  build/make и build/soong, shell-синтаксис и git diff.

Фрагменты логов и сводка: validation/.

## Запуск на машине для сборки

Нужен Linux x86_64 с зависимостями LineageOS 20, рабочим repo, доступом к GitHub
и android.googlesource.com. Для исходников и out выделить несколько сотен GiB.
Команды запускают эксперимент: ещё не перенесённые компоненты могут не собраться.

Получить bootstrap отдельно от Android checkout:

```bash
git clone -b lineage-20.0-experimental \
  https://github.com/skb8/android_device_samsung_espresso3g-1.git espresso-bootstrap
mkdir android-espresso20
cd android-espresso20
repo init -u https://github.com/rINanDO/android.git \
  -b 5539bd1a78111bd59459dbd5eea67c6a42378add --depth=1
mkdir -p .repo/local_manifests
cp ../espresso-bootstrap/porting/local_manifest.xml .repo/local_manifests/espresso.xml
repo sync -c -j4 --no-tags --no-clone-bundle
repo manifest -r -o sources-resolved.xml
bash device/samsung/espresso3g/porting/build.sh "$PWD"
```

prepare.sh применяет патч общей конфигурации с проверкой, повторно не применяет.
Runner сохраняет out/espresso-port-logs/build.log; pipefail сохраняет код ошибки.

## Оставшаяся работа

Следующий bootstrap после замены Soong показал отсутствие AddIncludeTags в
старом Blueprint (android-13.0.0_r13). Теперь build/blueprint закреплён на SHA
ca8f0e8e3571c866d69d34cbd47b3989abe8e8cd из android-13.0.0_r75 — тега,
используемого официальным manifest LineageOS 20 для AOSP-проектов. Наличие
метода AddIncludeTags проверено в context.go этого коммита. Репозиторий и remote
Blueprint остаются прежними (platform/build/blueprint, aosp), меняется revision.
После обновления local manifest нужен целевой repo sync build/blueprint.
Полный запуск bootstrap с этой комбинацией ещё не проверен локально.

После bootstrap Soong пользовательская сборка обнаружила несовместимые свойства
`upstream` и `soong_config_variables.*.export_cflags`. В исходном manifest был
закреплён старый форк rINanDO/build_soong, тогда как часть базовых проектов
скачивалась из более новой lineage-20.0. Для build/soong теперь выбран
LineageOS/android_build_soong, SHA c80e6e3b82f2c0fded69b44b514d4c4d5519c9b5:
в java/robolectric.go есть Upstream, в cc/library.go — Export_cflags.
После обновления device tree скопировать обновлённый local manifest в
.repo/local_manifests/espresso.xml и выполнить целевой repo sync build/soong.
Android.bp тестов и vendor/lineage ради обхода ошибок не меняются. Новая
композиция пока не проверена полным пользовательским запуском Soong.

Первый запуск на пользовательской машине после успешного repo sync дошёл до
dumpvars и остановился на `BOARD_USE_TI_LIBION: export is obsolete`.
Патч 0002 удаляет устаревший export, сохраняя значение переменной, и убирает
вызов add_lunch_combo из общего vendorsetup.sh. Применение и повторный запуск
патча проверены; повторный Android dumpvars ожидается на машине пользователя.
Сообщение roomservice `Device espresso3g not found` после этой ошибки было
следствием неуспешного dumpvars, а не отсутствующего device tree.

Следующий пользовательский запуск остановился на обязательном DEXPREOPT для
userdebug. Патч 0003 включает WITH_DEXPREOPT и ограничивает предкомпиляцию boot
image и system server. Это поддерживаемый конфигурацией Android 13 режим;
полная предкомпиляция приложений на этапе bring-up не включается. Применение
патча проверено, Android dumpvars после него ожидается на машине пользователя.

1. Общий espressowifi и TI hardware пока из Android 9. Проверить/обновить
   пакеты, include-пути, HAL, XML audio policy, VINTF и SELinux.
2. PowerVR: gralloc, HWC, EGL/GLES и синхронизация буферов. Exynos/Mali от S2
   напрямую не переносятся.
3. Совместимость userspace с отсутствующим memfd, старым LMK и ядром 3.4.
   Один флаг в BoardConfig не добавляет kernel backport.
4. system/bpf, system/netd, frameworks/libs/net и Connectivity содержат старые
   сетевые пути; работоспособность сети на OMAP не проверена.
5. TI OMX/Ducati, GPS, RIL, камера и совместимость vendor-библиотек с bionic.
6. System в общей конфигурации остаётся 1 GiB. Изменять размер в makefile без
   согласования с физической разметкой устройства нельзя.

Общая BoardConfig уже содержит SELinux permissive; эта унаследованная отладочная
конфигурация пока не доведена до enforcing.

Порядок: конфигурация/сборка, init и ADB, system_server, графика, периферия.
До теста на устройстве нужны точная модель GT-P3100/GT-P5100, разметка и резервная
копия. Команд прошивки здесь нет.

## Контрольная сборка ядра отдельно

```bash
mkdir -p kernel-out build-tmp
export TMPDIR="$PWD/build-tmp"
make -C kernel/ti/omap4 O="$PWD/kernel-out" ARCH=arm espresso_defconfig
make -C kernel/ti/omap4 O="$PWD/kernel-out" ARCH=arm \
  CROSS_COMPILE="$PWD/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-" \
  -j4 zImage
```

В выбранном GCC arm-linux-androideabi-gcc — Python wrapper с /usr/bin/python.
В этой среде shebang локально заменён на /usr/bin/env python3; бинарник GCC и
исходники ядра не менялись. Для повторения нужен рабочий интерпретатор wrapper.
zImage без ramdisk не является прошивкой планшета.
