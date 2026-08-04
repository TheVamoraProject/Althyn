import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Window
import com.vamora.welcome

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    title: "VamoraOS Setup"
    color: "transparent"

    // Fonts
    FontLoader { id: interRegular;  source: "assets/fonts/inter/Inter-Regular.ttf"  }
    FontLoader { id: interMedium;   source: "assets/fonts/inter/Inter-Medium.ttf"   }
    FontLoader { id: interSemiBold; source: "assets/fonts/inter/Inter-SemiBold.ttf" }
    FontLoader { id: interBold;     source: "assets/fonts/inter/Inter-Bold.ttf"     }

    // Rust
    WelcomeController { id: controller }
    Component.onCompleted: {
        root.osName      = controller.os_name()
        root.selectedLang = controller.locale_code()
    }

    // State
    property int  langIndex:   0
    property bool hasStarted:  false
    property int  currentPage: 0
    readonly property bool onDetailPage:   currentPage === 4
    readonly property bool onChooserPage:  currentPage === 3
    readonly property bool onAllSetPage:   currentPage === 5
    readonly property bool onLangPage:     currentPage === 1
    readonly property bool pillSingleBack: onDetailPage

    property string osName:       ""   // Takes it from /etc/os-release on start
    property string selectedLang: ""   // language chosen
    property string selectedChoice: ""   // Try Or install

    readonly property bool fwdEnabled: {
        if (onLangPage)    return selectedLang !== ""
        if (onChooserPage) return selectedChoice !== ""
        return true
    }

    // Animation
    property int  helloCharCount: 0     // typewriter character counter
    property bool introAnimDone:  false // typewriter state
    property int  _prevPage:      0     // previous page
    property bool _pagesReady:    false // so the animation dosnt start before the page is displayed
    property real cornerRadius: root.visibility === Window.FullScreen ? 0 : 20

    // the languages
    readonly property var greetings: [
        { hello: "Hello!",        ready: "Are you ready?"        },
        { hello: "¡Hola!",        ready: "¿Estás listo?"         },
        { hello: "Bonjour !",     ready: "Êtes-vous prêt ?"      },
        { hello: "你好！",         ready: "你准备好了吗？"         },
        { hello: "مرحباً!",       ready: "هل أنت مستعد؟"        },
        { hello: "こんにちは！",  ready: "準備はいいですか？"     },
        { hello: "Hallo!",        ready: "Bist du bereit?"       },
        { hello: "Ciao!",         ready: "Sei pronto?"           },
        { hello: "Olá!",          ready: "Você está pronto?"     },
        { hello: "Привет!",       ready: "Готов?"                },
        { hello: "Merhaba!",      ready: "Hazır mısın?"          },
        { hello: "नमस्ते!",       ready: "क्या आप तैयार हैं?"    },
        { hello: "Hej!",          ready: "Är du redo?"           },
        { hello: "سلام!",         ready: "آماده‌ای؟"             },
        { hello: "Γεια σου!",     ready: "Είσαι έτοιμος;"        },
        { hello: "Hello!",        ready: "C'mon start the setup already"        },
    ]

    // Language list shown on page 2 — sorted alphabetically by English name.
    // Each entry: code = POSIX locale code, native = name in its own script,
    // english = English name (empty string for English itself).
    readonly property var languages: [
        { code: "ar_SA.UTF-8", native: "العربية",         english: "Arabic"               },
        { code: "zh_CN.UTF-8", native: "中文（简体）",     english: "Chinese (Simplified)"  },
        { code: "zh_TW.UTF-8", native: "中文（繁體）",     english: "Chinese (Traditional)" },
        { code: "cs_CZ.UTF-8", native: "Čeština",          english: "Czech"                },
        { code: "da_DK.UTF-8", native: "Dansk",             english: "Danish"               },
        { code: "nl_NL.UTF-8", native: "Nederlands",        english: "Dutch"                },
        { code: "en_US.UTF-8", native: "English",           english: ""                     },
        { code: "fi_FI.UTF-8", native: "Suomi",             english: "Finnish"              },
        { code: "fr_FR.UTF-8", native: "Français",          english: "French"               },
        { code: "de_DE.UTF-8", native: "Deutsch",           english: "German"               },
        { code: "el_GR.UTF-8", native: "Ελληνικά",          english: "Greek"                },
        { code: "he_IL.UTF-8", native: "עברית",             english: "Hebrew"               },
        { code: "hi_IN.UTF-8", native: "हिन्दी",             english: "Hindi"                },
        { code: "hu_HU.UTF-8", native: "Magyar",            english: "Hungarian"            },
        { code: "id_ID.UTF-8", native: "Bahasa Indonesia",  english: "Indonesian"           },
        { code: "it_IT.UTF-8", native: "Italiano",          english: "Italian"              },
        { code: "ja_JP.UTF-8", native: "日本語",             english: "Japanese"             },
        { code: "ko_KR.UTF-8", native: "한국어",             english: "Korean"               },
        { code: "nb_NO.UTF-8", native: "Norsk Bokmål",      english: "Norwegian"            },
        { code: "fa_IR.UTF-8", native: "فارسی",             english: "Persian"              },
        { code: "pl_PL.UTF-8", native: "Polski",            english: "Polish"               },
        { code: "pt_BR.UTF-8", native: "Português",         english: "Portuguese (Brazil)"  },
        { code: "pt_PT.UTF-8", native: "Português",         english: "Portuguese (Portugal)"},
        { code: "ro_RO.UTF-8", native: "Română",            english: "Romanian"             },
        { code: "ru_RU.UTF-8", native: "Русский",           english: "Russian"              },
        { code: "es_ES.UTF-8", native: "Español",           english: "Spanish"              },
        { code: "sv_SE.UTF-8", native: "Svenska",           english: "Swedish"              },
        { code: "tr_TR.UTF-8", native: "Türkçe",            english: "Turkish"              },
        { code: "uk_UA.UTF-8", native: "Українська",        english: "Ukrainian"            },
        { code: "vi_VN.UTF-8", native: "Tiếng Việt",        english: "Vietnamese"           },
    ]

    // ── UI translations — keyed by 2-letter POSIX lang code; "zh_CN" / "zh_TW"
    // for the Simplified / Traditional split.  Keys:
    //   setup        top-bar title
    //   welcome      all-caps subtitle on Welcome page
    //   tosPrefix    text before the ToS link
    //   tosLink      clickable ToS link text
    //   chooser      "Choose your path" heading
    //   install      Install card label
    //   tryBtn       Try card label
    //   allSetTitle  "You're all set!" heading
    //   allSetSub    subtitle after osName on the All-set page
    //   tosTitle     Terms of Service page heading
    //   langTitle    Language-selection page heading
    readonly property var _tr: ({
        "en":   { setup:"VamoraOS Setup",          welcome:"WELCOME TO YOUR NEW HOME",
                  tosPrefix:"by continuing you are accepting our ", tosLink:"Terms of Service",
                  chooser:"Choose your path",       install:"Install",      tryBtn:"Try",
                  allSetTitle:"You're all set!",    allSetSub:"is ready to try",
                  tosTitle:"Terms of Service",      langTitle:"Select Language" },
        "ar":   { setup:"إعداد VamoraOS",           welcome:"مرحباً بك في منزلك الجديد",
                  tosPrefix:"بالمتابعة، أنت توافق على ", tosLink:"شروط الخدمة",
                  chooser:"اختر مسارك",             install:"تثبيت",         tryBtn:"تجربة",
                  allSetTitle:"أنت جاهز تماماً!",  allSetSub:"جاهز للتجربة",
                  tosTitle:"شروط الخدمة",           langTitle:"اختر اللغة" },
        "zh_CN":{ setup:"VamoraOS 设置",            welcome:"欢迎来到您的新家",
                  tosPrefix:"继续即表示同意",        tosLink:"服务条款",
                  chooser:"选择您的方式",            install:"安装",          tryBtn:"试用",
                  allSetTitle:"一切就绪！",          allSetSub:"已准备好试用",
                  tosTitle:"服务条款",               langTitle:"选择语言" },
        "zh_TW":{ setup:"VamoraOS 設定",            welcome:"歡迎來到您的新家",
                  tosPrefix:"繼續即表示同意",        tosLink:"服務條款",
                  chooser:"選擇您的方式",            install:"安裝",          tryBtn:"試用",
                  allSetTitle:"一切就緒！",          allSetSub:"已準備好試用",
                  tosTitle:"服務條款",               langTitle:"選擇語言" },
        "cs":   { setup:"Nastavení VamoraOS",       welcome:"VÍTEJTE VE VAŠEM NOVÉM DOMOVĚ",
                  tosPrefix:"pokračováním přijímáte naše ", tosLink:"Podmínky služby",
                  chooser:"Vyberte svou cestu",     install:"Nainstalovat", tryBtn:"Vyzkoušet",
                  allSetTitle:"Vše připraveno!",    allSetSub:"je připraven k vyzkoušení",
                  tosTitle:"Podmínky služby",        langTitle:"Vyberte jazyk" },
        "da":   { setup:"VamoraOS Opsætning",       welcome:"VELKOMMEN TIL DIT NYE HJEM",
                  tosPrefix:"ved at fortsætte accepterer du vores ", tosLink:"Servicevilkår",
                  chooser:"Vælg din vej",           install:"Installer",     tryBtn:"Prøv",
                  allSetTitle:"Alt er klar!",       allSetSub:"er klar til at prøve",
                  tosTitle:"Servicevilkår",          langTitle:"Vælg sprog" },
        "nl":   { setup:"VamoraOS Installatie",     welcome:"WELKOM IN UW NIEUWE THUIS",
                  tosPrefix:"door verder te gaan accepteer je onze ", tosLink:"Servicevoorwaarden",
                  chooser:"Kies uw pad",            install:"Installeren",   tryBtn:"Proberen",
                  allSetTitle:"Alles klaar!",       allSetSub:"is klaar om te proberen",
                  tosTitle:"Servicevoorwaarden",     langTitle:"Taal selecteren" },
        "fi":   { setup:"VamoraOS Asennus",         welcome:"TERVETULOA UUTEEN KOTIISI",
                  tosPrefix:"jatkamalla hyväksyt ",  tosLink:"käyttöehdot",
                  chooser:"Valitse polkusi",         install:"Asenna",        tryBtn:"Kokeile",
                  allSetTitle:"Kaikki valmista!",   allSetSub:"on valmis kokeiltavaksi",
                  tosTitle:"Käyttöehdot",            langTitle:"Valitse kieli" },
        "fr":   { setup:"Configuration VamoraOS",   welcome:"BIENVENUE DANS VOTRE NOUVEAU FOYER",
                  tosPrefix:"en continuant, vous acceptez nos ", tosLink:"Conditions d'utilisation",
                  chooser:"Choisissez votre parcours", install:"Installer",  tryBtn:"Essayer",
                  allSetTitle:"C'est parti !",      allSetSub:"est prêt à être essayé",
                  tosTitle:"Conditions d'utilisation", langTitle:"Choisir la langue" },
        "de":   { setup:"VamoraOS Einrichtung",     welcome:"WILLKOMMEN IN IHREM NEUEN ZUHAUSE",
                  tosPrefix:"durch Fortfahren akzeptieren Sie unsere ", tosLink:"Nutzungsbedingungen",
                  chooser:"Wählen Sie Ihren Weg",   install:"Installieren",  tryBtn:"Ausprobieren",
                  allSetTitle:"Alles bereit!",      allSetSub:"ist bereit zum Ausprobieren",
                  tosTitle:"Nutzungsbedingungen",    langTitle:"Sprache wählen" },
        "el":   { setup:"Ρύθμιση VamoraOS",         welcome:"ΚΑΛΩΣ ΗΡΘΑΤΕ ΣΤΟ ΝΕΟ ΣΑΣ ΣΠΙΤΙ",
                  tosPrefix:"συνεχίζοντας, αποδέχεστε τους ", tosLink:"Όρους Υπηρεσίας",
                  chooser:"Επιλέξτε τον δρόμο σας", install:"Εγκατάσταση", tryBtn:"Δοκιμή",
                  allSetTitle:"Όλα έτοιμα!",        allSetSub:"είναι έτοιμο για δοκιμή",
                  tosTitle:"Όροι Υπηρεσίας",         langTitle:"Επιλογή γλώσσας" },
        "he":   { setup:"הגדרת VamoraOS",           welcome:"ברוכים הבאים לביתכם החדש",
                  tosPrefix:"על ידי המשך, אתה מסכים ל", tosLink:"תנאי השירות",
                  chooser:"בחר את הדרך שלך",        install:"התקן",          tryBtn:"נסה",
                  allSetTitle:"הכל מוכן!",          allSetSub:"מוכן לניסיון",
                  tosTitle:"תנאי השירות",            langTitle:"בחר שפה" },
        "hi":   { setup:"VamoraOS सेटअप",           welcome:"अपने नए घर में आपका स्वागत है",
                  tosPrefix:"जारी रखने से आप हमारी ", tosLink:"सेवा शर्तें स्वीकार करते हैं",
                  chooser:"अपना रास्ता चुनें",      install:"इंस्टॉल करें",  tryBtn:"आज़माएं",
                  allSetTitle:"सब तैयार है!",       allSetSub:"आज़माने के लिए तैयार है",
                  tosTitle:"सेवा की शर्तें",         langTitle:"भाषा चुनें" },
        "hu":   { setup:"VamoraOS Beállítás",       welcome:"ÜDVÖZÖLJÜK AZ ÚJ OTTHONÁBAN",
                  tosPrefix:"a folytatással elfogadja a ", tosLink:"Felhasználási feltételeket",
                  chooser:"Válasszon utat",          install:"Telepítés",     tryBtn:"Kipróbálás",
                  allSetTitle:"Minden készen áll!", allSetSub:"kipróbálásra kész",
                  tosTitle:"Felhasználási feltételek", langTitle:"Nyelv kiválasztása" },
        "id":   { setup:"Pengaturan VamoraOS",      welcome:"SELAMAT DATANG DI RUMAH BARU ANDA",
                  tosPrefix:"dengan melanjutkan, Anda menyetujui ", tosLink:"Ketentuan Layanan",
                  chooser:"Pilih jalur Anda",        install:"Instal",        tryBtn:"Coba",
                  allSetTitle:"Semuanya siap!",      allSetSub:"siap untuk dicoba",
                  tosTitle:"Ketentuan Layanan",       langTitle:"Pilih bahasa" },
        "it":   { setup:"Configurazione VamoraOS",  welcome:"BENVENUTO NELLA TUA NUOVA CASA",
                  tosPrefix:"continuando, accetti i nostri ", tosLink:"Termini di servizio",
                  chooser:"Scegli il tuo percorso", install:"Installare",    tryBtn:"Provare",
                  allSetTitle:"Tutto pronto!",       allSetSub:"è pronto per essere provato",
                  tosTitle:"Termini di servizio",    langTitle:"Seleziona la lingua" },
        "ja":   { setup:"VamoraOS セットアップ",     welcome:"新しいホームへようこそ",
                  tosPrefix:"続行することで ",         tosLink:"利用規約に同意",
                  chooser:"プランを選択",            install:"インストール",   tryBtn:"試す",
                  allSetTitle:"準備完了！",           allSetSub:"を試す準備ができました",
                  tosTitle:"利用規約",                langTitle:"言語を選択" },
        "ko":   { setup:"VamoraOS 설정",             welcome:"새로운 홈에 오신 것을 환영합니다",
                  tosPrefix:"계속하면 당사의 ",       tosLink:"서비스 약관에 동의",
                  chooser:"경로를 선택하세요",        install:"설치",          tryBtn:"체험",
                  allSetTitle:"모든 준비 완료!",     allSetSub:"체험 준비가 되었습니다",
                  tosTitle:"서비스 약관",             langTitle:"언어 선택" },
        "nb":   { setup:"VamoraOS Oppsett",         welcome:"VELKOMMEN TIL DITT NYE HJEM",
                  tosPrefix:"ved å fortsette godtar du våre ", tosLink:"Vilkår for bruk",
                  chooser:"Velg din vei",            install:"Installer",     tryBtn:"Prøv",
                  allSetTitle:"Alt klart!",          allSetSub:"er klar til å prøves",
                  tosTitle:"Vilkår for bruk",        langTitle:"Velg språk" },
        "fa":   { setup:"راه‌اندازی VamoraOS",      welcome:"به خانه جدیدتان خوش آمدید",
                  tosPrefix:"با ادامه دادن، ",       tosLink:"شرایط خدمات را می‌پذیرید",
                  chooser:"مسیر خود را انتخاب کنید", install:"نصب",          tryBtn:"امتحان",
                  allSetTitle:"همه چیز آماده است!", allSetSub:"آماده امتحان است",
                  tosTitle:"شرایط خدمات",            langTitle:"انتخاب زبان" },
        "pl":   { setup:"Konfiguracja VamoraOS",    welcome:"WITAJ W SWOIM NOWYM DOMU",
                  tosPrefix:"kontynuując, akceptujesz nasze ", tosLink:"Warunki korzystania",
                  chooser:"Wybierz swoją ścieżkę",  install:"Zainstaluj",    tryBtn:"Wypróbuj",
                  allSetTitle:"Wszystko gotowe!",    allSetSub:"jest gotowy do wypróbowania",
                  tosTitle:"Warunki korzystania",    langTitle:"Wybierz język" },
        "pt":   { setup:"Configuração VamoraOS",    welcome:"BEM-VINDO À SUA NOVA CASA",
                  tosPrefix:"ao continuar, você aceita nossos ", tosLink:"Termos de serviço",
                  chooser:"Escolha o seu caminho",  install:"Instalar",      tryBtn:"Experimentar",
                  allSetTitle:"Tudo pronto!",        allSetSub:"está pronto para experimentar",
                  tosTitle:"Termos de serviço",      langTitle:"Selecionar idioma" },
        "ro":   { setup:"Configurare VamoraOS",     welcome:"BUN VENIT ÎN NOUL TĂU ACASĂ",
                  tosPrefix:"continuând, ești de acord cu ", tosLink:"Termenii serviciului",
                  chooser:"Alege calea ta",          install:"Instalează",    tryBtn:"Încearcă",
                  allSetTitle:"Totul e gata!",       allSetSub:"este gata de încercat",
                  tosTitle:"Termenii serviciului",   langTitle:"Selectați limba" },
        "ru":   { setup:"Настройка VamoraOS",       welcome:"ДОБРО ПОЖАЛОВАТЬ В ВАШ НОВЫЙ ДОМ",
                  tosPrefix:"продолжая, вы принимаете наши ", tosLink:"Условия использования",
                  chooser:"Выберите путь",           install:"Установить",    tryBtn:"Попробовать",
                  allSetTitle:"Готово!",             allSetSub:"готов к пробному запуску",
                  tosTitle:"Условия использования",  langTitle:"Выбрать язык" },
        "es":   { setup:"Configuración VamoraOS",   welcome:"BIENVENIDO A TU NUEVO HOGAR",
                  tosPrefix:"al continuar, aceptas nuestros ", tosLink:"Términos de servicio",
                  chooser:"Elige tu camino",         install:"Instalar",      tryBtn:"Probar",
                  allSetTitle:"¡Todo listo!",        allSetSub:"está listo para probar",
                  tosTitle:"Términos de servicio",   langTitle:"Seleccionar idioma" },
        "sv":   { setup:"VamoraOS Inställning",     welcome:"VÄLKOMMEN TILL DITT NYA HEM",
                  tosPrefix:"genom att fortsätta godkänner du våra ", tosLink:"Användarvillkor",
                  chooser:"Välj din väg",            install:"Installera",    tryBtn:"Prova",
                  allSetTitle:"Allt klart!",         allSetSub:"är redo att prova",
                  tosTitle:"Användarvillkor",         langTitle:"Välj språk" },
        "tr":   { setup:"VamoraOS Kurulumu",        welcome:"YENİ EVİNİZE HOŞ GELDİNİZ",
                  tosPrefix:"devam ederek ",          tosLink:"Hizmet Şartlarımızı kabul edersiniz",
                  chooser:"Yolunuzu seçin",          install:"Yükle",         tryBtn:"Dene",
                  allSetTitle:"Her şey hazır!",      allSetSub:"denemeye hazır",
                  tosTitle:"Hizmet Şartları",         langTitle:"Dil seçin" },
        "uk":   { setup:"Налаштування VamoraOS",    welcome:"ЛАСКАВО ПРОСИМО ДО ВАШОГО НОВОГО ДОМУ",
                  tosPrefix:"продовжуючи, ви приймаєте наші ", tosLink:"Умови використання",
                  chooser:"Оберіть свій шлях",       install:"Встановити",    tryBtn:"Спробувати",
                  allSetTitle:"Все готово!",         allSetSub:"готовий до спроби",
                  tosTitle:"Умови використання",     langTitle:"Вибрати мову" },
        "vi":   { setup:"Thiết lập VamoraOS",       welcome:"CHÀO MỪNG ĐẾN NGÔI NHÀ MỚI CỦA BẠN",
                  tosPrefix:"bằng cách tiếp tục, bạn đồng ý với ", tosLink:"Điều khoản dịch vụ",
                  chooser:"Chọn con đường của bạn", install:"Cài đặt",       tryBtn:"Dùng thử",
                  allSetTitle:"Tất cả đã sẵn sàng!", allSetSub:"sẵn sàng để dùng thử",
                  tosTitle:"Điều khoản dịch vụ",    langTitle:"Chọn ngôn ngữ" },
    })

    // Returns the translation object for the active language.
    // Checks the 5-char prefix first (distinguishes zh_CN from zh_TW),
    // then the 2-char language code, then falls back to English.
    readonly property var i18n: {
        var c5 = root.selectedLang.substring(0, 5)      // e.g. "zh_CN"
        var c2 = root.selectedLang.split("_")[0]        // e.g. "zh"
        return _tr[c5] || _tr[c2] || _tr["en"]
    }

    // timer for switching
    Timer {
        id: langTimer
        interval: 3200
        running: !root.hasStarted
        repeat: true
        onTriggered: langFadeOut.start()
    }

    SequentialAnimation {
        id: langFadeOut
        NumberAnimation {
            target: greetGroup; property: "opacity"
            to: 0; duration: 280; easing.type: Easing.InQuad
        }
        ScriptAction {
            script: root.langIndex = (root.langIndex + 1) % root.greetings.length
        }
        NumberAnimation {
            target: greetGroup; property: "opacity"
            to: 1; duration: 280; easing.type: Easing.OutQuad
        }
    }

    // ── Typewriter: bouncy character-reveal for "Hello!" (intro only) ──────
    Timer {
        id: typewriterTimer
        interval: 85
        running: true
        repeat: true
        onTriggered: {
            if (root.helloCharCount < root.greetings[0].hello.length) {
                root.helloCharCount++
                charBounce.restart()
            } else {
                root.introAnimDone = true
                typewriterTimer.stop()
            }
        }
    }


    // ── Battery status ─────────────────────────────────────────────────────
    property int  batteryPercent:  controller.battery_percent()
    property bool batteryCharging: controller.battery_charging()

    Timer {
        interval: 15000; running: true; repeat: true
        onTriggered: {
            root.batteryPercent  = controller.battery_percent()
            root.batteryCharging = controller.battery_charging()
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // SCENE ROOT — everything gets clipped to cornerRadius as one unit
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: sceneRoot
        anchors.fill: parent
        layer.enabled: root.cornerRadius > 0
        layer.effect: OpacityMask {
            maskSource: cornerMask
        }

    // ══════════════════════════════════════════════════════════════════════
    // BACKGROUND  — light-blue base + blurred floating blobs
    // ══════════════════════════════════════════════════════════════════════

    // Base layer (also used as ShaderEffectSource for the card blur)
    Item {
        id: bgScene
        anchors.fill: parent

        Image {
            anchors.fill: parent
            source: "assets/backgrounds/background.jpg"
            fillMode: Image.PreserveAspectCrop
        }


    // ══════════════════════════════════════════════════════════════════════
    // FROSTED-GLASS CARD
    // ══════════════════════════════════════════════════════════════════════

    // Capture the background under the card for backdrop blur
    ShaderEffectSource {
        id: cardBgCapture
        sourceItem: bgScene
        anchors.fill: frostedCard
        sourceRect: Qt.rect(frostedCard.x, frostedCard.y, frostedCard.width, frostedCard.height)
        visible: false
        live: true
    }

    // The card — clip: true rounds the blur + content together
    Rectangle {
        id: frostedCard
        width:  Math.min(root.width  * 0.70, 810)
        height: Math.min(root.height * 0.81, 550)
        anchors.centerIn: parent
        radius: 24
        clip: true
        color: "transparent"

        // Layer 1: blurred background
        FastBlur {
            anchors.fill: parent
            source: cardBgCapture
            radius: 48
        }

        // Layer 2: frosted white overlay
        Rectangle {
            anchors.fill: parent
            radius: frostedCard.radius
            color: Qt.rgba(1, 1, 1, 0.40)
        }

        // Layer 3: 1 px border (sits on top so radius matches)
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: frostedCard.radius
            border.color: Qt.rgba(1, 1, 1, 0.68)
            border.width: 1
        }

        // ── PAGE 0 : Hello ─────────────────────────────────────────────────
        Item {
            id: helloPage
            anchors.fill: parent
            opacity: 1                          // managed by transition system
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: helloPage.pageSlide }

            Column {
                id: greetGroup
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -24
                spacing: 10

                Text {
                    id: helloText
                    // Intro: show only typed portion of the first greeting.
                    // After intro: follow the cycling language index normally.
                    text: root.introAnimDone
                          ? root.greetings[root.langIndex].hello
                          : root.greetings[0].hello.substring(0, root.helloCharCount)
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.105, 64)
                    font.weight: Font.Bold
                    color: "#111111"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    id: readyText
                    text: root.greetings[root.langIndex].ready
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.037, 22)
                    font.weight: Font.Normal
                    color: "#555555"
                    // Hidden until typewriter completes, then fades in once.
                    // greetGroup's opacity handles the cycling animation after that.
                    opacity: root.introAnimDone ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.OutQuad } }
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ── PAGE 2 : Welcome / ToS ─────────────────────────────────────────
        Item {
            id: tosPage
            anchors.fill: parent
            opacity: 0                          // managed by transition system
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: tosPage.pageSlide }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -24
                spacing: 10

                // Vamora logo
                Image {
                    id: vamoraLogo
                    source: "assets/Vamora.svg"
                    width: 88;  height: 88
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Vamora"
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.078, 48)
                    font.weight: Font.Bold
                    color: "#111111"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: root.i18n.welcome
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.026, 16)
                    font.weight: Font.Medium
                    font.letterSpacing: 1.6
                    color: "#333333"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // ToS line with clickable link
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Text {
                        text: root.i18n.tosPrefix
                        font.family: "Inter"
                        font.pixelSize: Math.min(frostedCard.width * 0.024, 14)
                        color: "#555555"
                    }

                    Text {
                        text: root.i18n.tosLink
                        font.family: "Inter"
                        font.pixelSize: Math.min(frostedCard.width * 0.024, 14)
                        color: "#4477DD"
                        font.underline: true

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // No internet during setup — show the ToS in-app
                            // instead of trying to open a browser.
                            onClicked: root.currentPage = 4
                        }
                    }
                }
            }
        }

        // ── PAGE 1 : Language Selection ────────────────────────────────────
        Item {
            id: langPage
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: langPage.pageSlide }

            // Header
            Text {
                id: langPageTitle
                anchors.top: parent.top
                anchors.topMargin: 26
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.i18n.langTitle
                font.family: "Inter"
                font.pixelSize: Math.min(frostedCard.width * 0.038, 24)
                font.weight: Font.SemiBold
                color: "#111111"
            }

            // Scrollable list
            ListView {
                id: langList
                anchors.top: langPageTitle.bottom
                anchors.topMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 82
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                clip: true
                model: root.languages
                spacing: 3
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: langRow
                    width: langList.width
                    height: 46
                    radius: 10
                    readonly property bool sel: root.selectedLang === modelData.code
                    color: sel
                           ? Qt.rgba(0.22, 0.53, 1.0, 0.15)
                           : langRowHover.containsMouse
                             ? Qt.rgba(0, 0, 0, 0.05)
                             : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: langRowHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedLang = modelData.code
                    }

                    // Native name + English label
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            text: modelData.native
                            font.family: "Inter"
                            font.pixelSize: 15
                            font.weight: langRow.sel ? Font.SemiBold : Font.Normal
                            color: langRow.sel ? "#2C6FEA" : "#111111"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.english
                            font.family: "Inter"
                            font.pixelSize: 13
                            color: "#888888"
                            visible: modelData.english !== ""
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Check mark when selected
                    Image {
                        id: langCheckImg
                        source: "assets/icons/check.svg"
                        width: 16; height: 16
                        sourceSize: Qt.size(width, height)
                        anchors.right: parent.right; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: false
                    }
                    ColorOverlay {
                        source: langCheckImg
                        anchors.fill: langCheckImg
                        color: "#2C6FEA"
                        visible: langRow.sel
                    }
                }
            }
        }

        // ── PAGE 4 : Terms of Service (full text, shown in-app) ────────────
        Item {
            id: tosDetailPage
            anchors.fill: parent
            opacity: 0                          // managed by transition system
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: tosDetailPage.pageSlide }

            Text {
                id: tosDetailTitle
                anchors.top: parent.top
                anchors.topMargin: 28
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.i18n.tosTitle
                font.family: "Inter"
                font.pixelSize: Math.min(frostedCard.width * 0.045, 24)
                font.weight: Font.Bold
                color: "#111111"
            }

            Flickable {
                id: tosFlick
                anchors.top: tosDetailTitle.bottom
                anchors.topMargin: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 78
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 34
                anchors.rightMargin: 34
                contentHeight: tosBody.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                Text {
                    id: tosBody
                    width: tosFlick.width
                    wrapMode: Text.WordWrap
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.0215, 13)
                    lineHeight: 1.4
                    color: "#333333"
                    text:
                        "This is placeholder Terms of Service text for VamoraOS. Replace it " +
                        "with your real terms before shipping.\n\n" +
                        "1. Acceptance of Terms\n" +
                        "By setting up and using VamoraOS, you agree to be bound by these terms. " +
                        "If you do not agree, please discontinue setup.\n\n" +
                        "2. Use of the Software\n" +
                        "VamoraOS is provided to help you manage your device. You agree to use it " +
                        "only for lawful purposes and in accordance with any additional policies " +
                        "provided with your device.\n\n" +
                        "3. Data and Privacy\n" +
                        "Details on what data VamoraOS collects, how it is stored, and how it is " +
                        "used will be described here. Replace this section with your actual " +
                        "privacy practices.\n\n" +
                        "4. Updates\n" +
                        "VamoraOS may receive updates that add, change, or remove functionality. " +
                        "Continued use of the software after an update constitutes acceptance of " +
                        "any revised terms.\n\n" +
                        "5. Limitation of Liability\n" +
                        "VamoraOS is provided \"as is\" without warranties of any kind, express or " +
                        "implied, to the fullest extent permitted by law.\n\n" +
                        "6. Contact\n" +
                        "Questions about these terms can be directed to your device's support " +
                        "channel."
                }
            }
        }

        // ── PAGE 3 : Install or Try ────────────────────────────────────────
        Item {
            id: chooserPage
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: chooserPage.pageSlide }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -16
                spacing: 20

                Text {
                    text: root.i18n.chooser
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.050, 30)
                    font.weight: Font.Bold
                    color: "#111111"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // ── Install card ────────────────────────────────────────
                    Rectangle {
                        id: installCard
                        readonly property bool selected: root.selectedChoice === "install"

                        width:  Math.min(frostedCard.width * 0.34, 172)
                        height: Math.min(frostedCard.height * 0.40, 158)
                        radius: 18
                        scale: selected ? 1.045 : 1.0
                        color:  selected
                                ? Qt.rgba(0.22, 0.53, 1.0, 0.22)
                                : installHover.containsMouse
                                  ? Qt.rgba(0.22, 0.53, 1.0, 0.18)
                                  : Qt.rgba(1, 1, 1, 0.52)
                        border.color: selected
                                      ? "#2C6FEA"
                                      : installHover.containsMouse
                                        ? Qt.rgba(0.22, 0.53, 1.0, 0.55)
                                        : Qt.rgba(1, 1, 1, 0.72)
                        border.width: selected ? 2.5 : 1.5
                        Behavior on scale        { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 4 } }
                        Behavior on color        { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }
                        Behavior on border.width { NumberAnimation { duration: 160 } }

                        HoverHandler { id: installHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // Tapping only selects the card — the forward
                            // arrow on the nav pill is what commits to it.
                            onClicked: root.selectedChoice = "install"
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                id: installIconSrc
                                width: 32;  height: 32
                                sourceSize: Qt.size(width, height)
                                source: "assets/icons/download.svg"
                                visible: false
                            }
                            ColorOverlay {
                                width: installIconSrc.width;  height: installIconSrc.height
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: installIconSrc
                                color: installCard.selected ? "#2C6FEA" : "#333333"
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                            Text {
                                text: root.i18n.install
                                font.family: "Inter"
                                font.pixelSize: Math.min(frostedCard.width * 0.030, 17)
                                font.weight: Font.SemiBold
                                color: "#111111"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: root.osName
                                font.family: "Inter"
                                font.pixelSize: Math.min(frostedCard.width * 0.023, 13)
                                color: "#555555"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // ── Try card ────────────────────────────────────────────
                    Rectangle {
                        id: tryCard
                        readonly property bool selected: root.selectedChoice === "try"

                        width:  Math.min(frostedCard.width * 0.34, 172)
                        height: Math.min(frostedCard.height * 0.40, 158)
                        radius: 18
                        scale: selected ? 1.045 : 1.0
                        color:  selected
                                ? Qt.rgba(0.22, 0.53, 1.0, 0.22)
                                : tryHover.containsMouse
                                  ? Qt.rgba(0.22, 0.53, 1.0, 0.18)
                                  : Qt.rgba(1, 1, 1, 0.52)
                        border.color: selected
                                      ? "#2C6FEA"
                                      : tryHover.containsMouse
                                        ? Qt.rgba(0.22, 0.53, 1.0, 0.55)
                                        : Qt.rgba(1, 1, 1, 0.72)
                        border.width: selected ? 2.5 : 1.5
                        Behavior on scale        { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 4 } }
                        Behavior on color        { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }
                        Behavior on border.width { NumberAnimation { duration: 160 } }

                        HoverHandler { id: tryHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // Tapping only selects the card — the forward
                            // arrow on the nav pill is what commits to it.
                            onClicked: root.selectedChoice = "try"
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                id: tryIconSrc
                                width: 32;  height: 32
                                sourceSize: Qt.size(width, height)
                                source: "assets/icons/play.svg"
                                visible: false
                            }
                            ColorOverlay {
                                width: tryIconSrc.width;  height: tryIconSrc.height
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: tryIconSrc
                                color: tryCard.selected ? "#2C6FEA" : "#333333"
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                            Text {
                                text: root.i18n.tryBtn
                                font.family: "Inter"
                                font.pixelSize: Math.min(frostedCard.width * 0.030, 17)
                                font.weight: Font.SemiBold
                                color: "#111111"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: root.osName
                                font.family: "Inter"
                                font.pixelSize: Math.min(frostedCard.width * 0.023, 13)
                                color: "#555555"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }

        // ── PAGE 5 : All set (Try mode confirmed) ──────────────────────────
        Item {
            id: allSetPage
            anchors.fill: parent
            opacity: 0
            visible: opacity > 0
            property real pageSlide: 0
            transform: Translate { y: allSetPage.pageSlide }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -28
                spacing: 10

                Image {
                    id: checkIconSrc
                    width: Math.min(frostedCard.width * 0.11, 60)
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "assets/icons/check.svg"
                    visible: false
                }
                ColorOverlay {
                    width: checkIconSrc.width;  height: checkIconSrc.height
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: checkIconSrc
                    color: "#2DBD6E"
                    scale: root.onAllSetPage ? 1.0 : 0.4
                    transformOrigin: Item.Center
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 6 } }
                }

                Text {
                    text: root.i18n.allSetTitle
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.075, 44)
                    font.weight: Font.Bold
                    color: "#111111"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: root.osName + " " + root.i18n.allSetSub
                    font.family: "Inter"
                    font.pixelSize: Math.min(frostedCard.width * 0.032, 19)
                    font.weight: Font.Normal
                    color: "#555555"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // ── NAVIGATION PILL ────────────────────────────────────────────────
        //
        //  Page 0 (not started):  [  →  ]  blue pill, single right arrow
        //  Page 1 (Welcome/ToS):  [  ←  →  ]  frosted, both arrows
        //  Page 2 (Install/Try):  [  ←  →  ]  frosted, both arrows — → is
        //                          grayed out/disabled until a card is picked
        //  Page 3 (ToS text):     [  ←  ]  frosted, single back arrow
        //  Page 4 (All set):      [  →  ]  blue pill again, single right arrow (exits)
        //
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            width:  navPill.width
            height: navPill.height

            Rectangle {
                id: navPill
                width: {
                    if (!root.hasStarted)    return 125   // initial blue → pill
                    if (root.pillSingleBack) return 125   // frosted ← only
                    if (root.onAllSetPage)   return 125   // frosted → only (exits)
                    return 150                            // frosted ← | →
                }
                height: 45
                radius: height / 2
                // All-set page matches the very first pill's blue, not the
                // frosted look used everywhere in between.
                readonly property bool isBluePill: !root.hasStarted || root.onAllSetPage
                color:  isBluePill ? "#4DA8FF" : Qt.rgba(1, 1, 1, 0.60)
                border.color: isBluePill ? "transparent" : Qt.rgba(0, 0, 0, 0.10)
                border.width: 1

                Behavior on width {
                    NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
                }
                Behavior on color   { ColorAnimation { duration: 240 } }
                Behavior on border.color { ColorAnimation { duration: 240 } }

                // ── Back button (dual-arrow state: page 1 only) ─────────────
                Item {
                    id: backBtn
                    visible: !root.pillSingleBack && !root.onAllSetPage
                    width: 84;  height: parent.height
                    anchors.left: parent.left
                    opacity: root.hasStarted ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.currentPage > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.hasStarted && root.currentPage > 1
                        onClicked: if (root.currentPage > 1) root.currentPage--
                    }

                    Image {
                        id: backArrow
                        anchors.centerIn: parent
                        width: 22;  height: 22
                        sourceSize: Qt.size(width, height)
                        source: "assets/icons/chevron-left.svg"
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: backArrow
                        source: backArrow
                        color: "#000000"
                        opacity: (root.hasStarted && root.currentPage > 1) ? 1.0 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                }

                // ── Forward button ──────────────────────────────────────────
                Item {
                    id: fwdBtn
                    visible: !root.pillSingleBack
                    // Takes full pill width on all-set page (no back button there)
                    width: (root.hasStarted && !root.onAllSetPage) ? 84 : parent.width
                    height: parent.height
                    anchors.right: parent.right
                    opacity: root.fwdEnabled ? 1.0 : 0.4
                    Behavior on width   { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.fwdEnabled
                        cursorShape: root.fwdEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!root.hasStarted) {
                                // First press: morph pill, go to Language selection
                                root.hasStarted  = true
                                root.currentPage = 1
                            } else if (root.onAllSetPage) {
                                // All-set page → exit to live session
                                controller.finish_setup()
                            } else if (root.onLangPage) {
                                // Apply the chosen locale then advance to Welcome/ToS
                                controller.apply_locale(root.selectedLang)
                                root.currentPage = 2
                            } else if (root.onChooserPage) {
                                // Commit whichever card was picked
                                if (root.selectedChoice === "install") {
                                    controller.launch_installer()
                                } else if (root.selectedChoice === "try") {
                                    root.currentPage = 5
                                }
                            } else if (root.currentPage < 3) {
                                // Page 2 (Welcome/ToS) → page 3 (Install/Try chooser)
                                root.currentPage++
                            }
                        }
                    }

                    Image {
                        anchors.centerIn: parent
                        width: 22;  height: 22
                        sourceSize: Qt.size(width, height)
                        source: "assets/icons/chevron-right.svg"
                        // Tint: white on blue pill, black on frosted pill
                        // Qt SVG colorization via ColorOverlay
                    }

                    ColorOverlay {
                        anchors.fill: fwdArrow
                        source: fwdArrow
                        color: navPill.isBluePill ? "#ffffff" : "#000000"
                        Behavior on color { ColorAnimation { duration: 240 } }
                    }

                    Image {
                        id: fwdArrow
                        anchors.centerIn: parent
                        width: 22;  height: 22
                        sourceSize: Qt.size(width, height)
                        source: "assets/icons/chevron-right.svg"
                        visible: false   // rendered only by the ColorOverlay above
                    }
                }

                // ── Back-only button (ToS detail page 3) ────────────────────
                Item {
                    id: backOnlyBtn
                    visible: root.pillSingleBack
                    anchors.fill: parent

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentPage = 1
                    }

                    Image {
                        id: backOnlyArrow
                        anchors.centerIn: parent
                        width: 22;  height: 22
                        sourceSize: Qt.size(width, height)
                        source: "assets/icons/chevron-left.svg"
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: backOnlyArrow
                        source: backOnlyArrow
                        color: "#000000"
                    }
                }
            }
        }
    }
    } // end bgScene

    // ══════════════════════════════════════════════════════════════════════
    // TOP BAR  ——  VAMORAOS  (left)   battery (right)
    // ══════════════════════════════════════════════════════════════════════

    Item {
        id: topBar
        x: 0;  y: 14
        width: parent.width;  height: 32

        Text {
            text: root.i18n.setup
            anchors.left: parent.left;  anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Bold
            font.letterSpacing: 2.0
            color: "#1a1a1a"
        }

        // Battery indicator — hidden entirely if no battery is detected
        // (e.g. running on a desktop dev box with no /sys/class/power_supply
        // BAT* entry).
        Row {
            anchors.right: parent.right;  anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: root.batteryPercent >= 0

            // ── Battery icon: outline + proportional fill + charging bolt ──
            Item {
                id: batteryIcon
                width: 22;  height: 13
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: batteryOutlineSrc
                    anchors.fill: parent
                    fillMode: Image.Stretch
                    sourceSize: Qt.size(width, height)
                    source: "assets/icons/battery.svg"
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: batteryOutlineSrc
                    source: batteryOutlineSrc
                    color: "#1a1a1a"
                }

                // Charge-level fill, inset inside the battery body
                Rectangle {
                    anchors.left: parent.left;   anchors.leftMargin: 3
                    anchors.top: parent.top;     anchors.topMargin: 3
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                    radius: 1
                    color: "#1a1a1a"
                    width: Math.max(0, (parent.width - 8) * (root.batteryPercent / 100))
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                }
            }

            // Charging bolt — sits beside the icon rather than on top of it,
            // so it stays visible black-on-light-background at any charge level.
            Item {
                width: 11;  height: 11
                anchors.verticalCenter: parent.verticalCenter
                visible: root.batteryCharging

                Image {
                    id: zapSrc
                    anchors.fill: parent
                    sourceSize: Qt.size(width, height)
                    source: "assets/icons/zap.svg"
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: zapSrc
                    source: zapSrc
                    color: "#1a1a1a"
                }
            }

            Text {
                text: root.batteryPercent + "%"
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#1a1a1a"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    } // end sceneRoot

    // Mask used by sceneRoot's OpacityMask — invisible, just defines the shape
    Rectangle {
        id: cornerMask
        anchors.fill: sceneRoot
        radius: root.cornerRadius
        visible: false
    }

    // ══════════════════════════════════════════════════════════════════════
    // PAGE TRANSITIONS  — slide + fade in/out on every page change
    // ══════════════════════════════════════════════════════════════════════

    // Wait one event-loop tick after startup so the initial state doesn't
    // trigger a spurious transition.
    Timer {
        id: pagesReadyTimer
        interval: 0; running: true; repeat: false
        onTriggered: root._pagesReady = true
    }

    onCurrentPageChanged: {
        if (!root._pagesReady) return

        var dir      = currentPage > _prevPage ? 1 : -1
        var allPages = [helloPage, langPage, tosPage, chooserPage, tosDetailPage, allSetPage]
        var leaving  = allPages[_prevPage]
        var entering = allPages[currentPage]
        _prevPage    = currentPage

        // When landing on the language page, scroll the list to the
        // pre-selected (system) language after the slide-in completes.
        if (currentPage === 1) scrollToLangTimer.restart()

        // Slide + fade the leaving page out
        leavingOpacity.target = leaving
        leavingOpacity.start()
        leavingSlide.target = leaving
        leavingSlide.to = -28 * dir
        leavingSlide.start()

        // Prime the entering page just off-screen, then bring it in
        entering.pageSlide = 28 * dir
        entering.opacity   = 0
        enterDelay.pendingPage = entering
        enterDelay.restart()
    }

    // ── Leaving page ───────────────────────────────────────────────────────
    NumberAnimation {
        id: leavingOpacity
        property: "opacity"; to: 0
        duration: 200; easing.type: Easing.InQuad
    }
    NumberAnimation {
        id: leavingSlide
        property: "pageSlide"
        duration: 220; easing.type: Easing.InQuad
    }

    // ── Entering page (starts slightly after leaving begins) ──────────────
    NumberAnimation {
        id: enteringOpacity
        property: "opacity"; to: 1
        duration: 310; easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: enteringSlide
        property: "pageSlide"; to: 0
        duration: 390; easing.type: Easing.OutBack
        easing.overshoot: 0.7
    }

    Timer {
        id: enterDelay
        interval: 55; repeat: false
        property var pendingPage: null
        onTriggered: {
            if (pendingPage === null) return
            enteringOpacity.target = pendingPage
            enteringOpacity.start()
            enteringSlide.target = pendingPage
            enteringSlide.start()
        }
    }

    // Scrolls the language list to the currently selected language.
    // Delayed so it fires after the page slide-in animation finishes.
    Timer {
        id: scrollToLangTimer
        interval: 460   // slide-in takes ~390 ms + 55 ms delay = ~445 ms
        repeat: false
        onTriggered: {
            if (root.selectedLang === "") return
            for (var i = 0; i < root.languages.length; i++) {
                if (root.languages[i].code === root.selectedLang) {
                    langList.positionViewAtIndex(i, ListView.Center)
                    return
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // KEYBOARD SHORTCUTS
    // ══════════════════════════════════════════════════════════════════════

    // Left/Right pick a card (Install is on the left, Try is on the right);
    // Enter/Return commits whichever one is currently selected — same as
    // tapping the forward arrow.
    Shortcut {
        sequence: "Left"
        enabled: root.onChooserPage
        onActivated: root.selectedChoice = "install"
    }
    Shortcut {
        sequence: "Right"
        enabled: root.onChooserPage
        onActivated: root.selectedChoice = "try"
    }
    Shortcut {
        sequence: "Return"
        enabled: root.onChooserPage && root.selectedChoice !== ""
        onActivated: {
            if (root.selectedChoice === "install") {
                controller.launch_installer()
            } else if (root.selectedChoice === "try") {
                root.currentPage = 5
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+Q"
        context: Qt.ApplicationShortcut
        onActivated: controller.request_exit()
    }

}
