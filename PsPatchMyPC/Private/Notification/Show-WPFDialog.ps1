function Show-WPFDialog {
    <#
    .SYNOPSIS
        Shows a WPF dialog window
    .DESCRIPTION
        Creates and displays a WPF dialog for user interaction
    .PARAMETER Xaml
        The XAML definition for the window
    .PARAMETER DataContext
        Data to bind to the window
    .PARAMETER Timeout
        Auto-close timeout in seconds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Xaml,
        
        [Parameter()]
        [hashtable]$DataContext,
        
        [Parameter()]
        [int]$Timeout = 300
    )
    
    Add-Type -AssemblyName PresentationFramework, System.Windows.Forms -ErrorAction SilentlyContinue
    
    try {
        [xml]$xamlXml = $Xaml
        $reader = New-Object System.Xml.XmlNodeReader $xamlXml
        $window = [Windows.Markup.XamlReader]::Load($reader)
        
        return $window
    }
    catch {
        Write-PatchLog "Failed to create WPF dialog: $_" -Type Error
        return $null
    }
}

function Get-DeferralDialogXaml {
    <#
    .SYNOPSIS
        Returns XAML for the deferral dialog
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "Update Required",
        
        [Parameter()]
        [string]$Message,
        
        [Parameter()]
        [string]$AppName,
        
        [Parameter()]
        [int]$DeferralsRemaining,
        
        [Parameter()]
        [string]$AccentColor = "#0078D4"
    )
    
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="320" Width="520"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Border CornerRadius="12" Background="#FF2D2D30" BorderBrush="$AccentColor" 
            BorderThickness="2" Margin="10">
        <Border.Effect>
            <DropShadowEffect BlurRadius="20" ShadowDepth="0" Opacity="0.6"/>
        </Border.Effect>
        <Grid Margin="25">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <!-- Header -->
            <StackPanel Grid.Row="0" Orientation="Horizontal">
                <TextBlock Text="&#xE7BA;" FontFamily="Segoe MDL2 Assets" 
                          FontSize="28" Foreground="#FFD83B01" Margin="0,0,12,0"/>
                <TextBlock Name="HeaderText" Text="$Title" 
                          FontSize="20" FontWeight="Bold" Foreground="White" 
                          VerticalAlignment="Center"/>
            </StackPanel>
            
            <!-- App Name -->
            <TextBlock Grid.Row="1" Name="AppNameText" Text="$AppName"
                      FontSize="16" Foreground="$AccentColor" Margin="0,15,0,5"/>
            
            <!-- Message -->
            <TextBlock Grid.Row="2" Name="MessageText" TextWrapping="Wrap" 
                      Foreground="#CCCCCC" FontSize="14" Margin="0,10">
                $Message
            </TextBlock>
            
            <!-- Countdown -->
            <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10">
                <TextBlock Text="Auto-installing in: " Foreground="#888888" FontSize="15"/>
                <TextBlock Name="CountdownText" Text="5:00" Foreground="$AccentColor" 
                          FontSize="15" FontWeight="Bold"/>
            </StackPanel>
            
            <!-- Buttons -->
            <StackPanel Grid.Row="4" Orientation="Horizontal" 
                       HorizontalAlignment="Right" Margin="0,15,0,0">
                <Button Name="DeferButton" Content="Defer ($DeferralsRemaining remaining)" Width="160" 
                       Height="36" Margin="0,0,12,0" Background="#FF3F3F3F" 
                       Foreground="White" BorderThickness="0" Cursor="Hand">
                    <Button.Style>
                        <Style TargetType="Button">
                            <Setter Property="Template">
                                <Setter.Value>
                                    <ControlTemplate TargetType="Button">
                                        <Border Background="{TemplateBinding Background}" 
                                                CornerRadius="4" Padding="10,5">
                                            <ContentPresenter HorizontalAlignment="Center" 
                                                            VerticalAlignment="Center"/>
                                        </Border>
                                    </ControlTemplate>
                                </Setter.Value>
                            </Setter>
                        </Style>
                    </Button.Style>
                </Button>
                <Button Name="UpdateButton" Content="Update Now" Width="120" 
                       Height="36" Background="$AccentColor" Foreground="White" 
                       BorderThickness="0" Cursor="Hand">
                    <Button.Style>
                        <Style TargetType="Button">
                            <Setter Property="Template">
                                <Setter.Value>
                                    <ControlTemplate TargetType="Button">
                                        <Border Background="{TemplateBinding Background}" 
                                                CornerRadius="4" Padding="10,5">
                                            <ContentPresenter HorizontalAlignment="Center" 
                                                            VerticalAlignment="Center"/>
                                        </Border>
                                    </ControlTemplate>
                                </Setter.Value>
                            </Setter>
                        </Style>
                    </Button.Style>
                </Button>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
}

function Get-ToastNotificationXaml {
    <#
    .SYNOPSIS
        Returns XAML for toast-style notification
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "Update Available",
        
        [Parameter()]
        [string]$Message,
        
        [Parameter()]
        [string]$AccentColor = "#0078D4"
    )
    
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Toast" Height="120" Width="400"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False">
    <Border CornerRadius="8" Background="#FF1F1F1F" BorderBrush="#FF3F3F3F" 
            BorderThickness="1" Margin="10">
        <Border.Effect>
            <DropShadowEffect BlurRadius="15" ShadowDepth="3" Opacity="0.5"/>
        </Border.Effect>
        <Grid Margin="15">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="40"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="30"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="&#xE7E7;" FontFamily="Segoe MDL2 Assets" 
                      FontSize="24" Foreground="$AccentColor" VerticalAlignment="Center"/>
            <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="10,0">
                <TextBlock Name="TitleText" Text="$Title" Foreground="White" 
                          FontSize="14" FontWeight="SemiBold"/>
                <TextBlock Name="MessageText" Text="$Message" Foreground="#AAAAAA" FontSize="12" 
                          TextWrapping="Wrap"/>
            </StackPanel>
            <Button Name="CloseButton" Grid.Column="2" Content="&#xE711;" 
                   FontFamily="Segoe MDL2 Assets" Background="Transparent" 
                   Foreground="#888888" BorderThickness="0" Cursor="Hand"/>
        </Grid>
    </Border>
</Window>
"@
}

function Get-RebootPromptDialogXaml {
    <#
    .SYNOPSIS
        Returns XAML for a reboot prompt dialog (Restart now / Later)
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "Restart Required",

        [Parameter()]
        [string]$Message = "Updates were installed and a restart is required to finish applying changes.",

        [Parameter()]
        [string]$AccentColor = "#0078D4",

        [Parameter()]
        [string]$CompanyName = "IT Department"
    )

    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="260" Width="520"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Border CornerRadius="12" Background="#FF2D2D30" BorderBrush="$AccentColor"
            BorderThickness="2" Margin="10">
        <Border.Effect>
            <DropShadowEffect BlurRadius="20" ShadowDepth="0" Opacity="0.6"/>
        </Border.Effect>
        <Grid Margin="25">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Header -->
            <StackPanel Grid.Row="0" Orientation="Horizontal">
                <TextBlock Text="&#xE777;" FontFamily="Segoe MDL2 Assets"
                          FontSize="28" Foreground="$AccentColor" Margin="0,0,12,0"/>
                <TextBlock Text="$Title" FontSize="20" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
            </StackPanel>

            <!-- Subheader -->
            <TextBlock Grid.Row="1" Text="$CompanyName" Foreground="#888888" FontSize="12" Margin="0,8,0,0"/>

            <!-- Message -->
            <TextBlock Grid.Row="2" TextWrapping="Wrap" Foreground="#CCCCCC" FontSize="14" Margin="0,15,0,0">
                $Message
            </TextBlock>

            <!-- Buttons -->
            <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
                <Button Name="LaterButton" Content="Later" Width="120" Height="36" Margin="0,0,12,0"
                        Background="#FF3F3F3F" Foreground="White" BorderThickness="0" Cursor="Hand"/>
                <Button Name="RestartButton" Content="Restart Now" Width="140" Height="36"
                        Background="$AccentColor" Foreground="White" BorderThickness="0" Cursor="Hand"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
}

function Get-FullScreenInterstitialXaml {
    <#
    .SYNOPSIS
        Returns XAML for a full-screen interstitial prompt (RUXIM-style)
    .DESCRIPTION
        Creates a full-screen, borderless, topmost window replicating Microsoft's
        Windows 11 upgrade prompt pattern (RUXIM). Designed for critical updates
        when deferral deadline has elapsed.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "Action Required",

        [Parameter()]
        [string]$Subtitle = "IT Department",

        [Parameter()]
        [string]$Headline = "Your device requires attention",

        [Parameter()]
        [string]$Message = "Important updates must be installed now. Please save your work. Your device may restart after updates are applied.",

        [Parameter()]
        [string]$AccentColor = "#0078D4",

        [Parameter()]
        [string]$UpdateButtonLabel = "Update Now",

        [Parameter()]
        [string]$DeferButtonLabel = "Remind me in 1 hour",

        [Parameter()]
        [bool]$ShowDeferButton = $false,

        [Parameter()]
        [string]$CountdownLabel = "Updating automatically in:",

        [Parameter()]
        [string]$HeroImagePath = ""
    )

    # Hero image section (optional)
    $heroImageSection = ""
    if ($HeroImagePath -and (Test-Path $HeroImagePath -ErrorAction SilentlyContinue)) {
        $heroImageSection = @"
            <!-- Hero Image -->
            <Image Grid.Row="0" Source="$HeroImagePath" Stretch="UniformToFill"
                   Height="200" HorizontalAlignment="Stretch" VerticalAlignment="Top"/>
"@
    }

    # Defer button visibility
    $deferVisibility = if ($ShowDeferButton) { "Visible" } else { "Collapsed" }

    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title"
        WindowStyle="None" AllowsTransparency="False"
        WindowState="Maximized" Topmost="True"
        ShowInTaskbar="False" ResizeMode="NoResize"
        Background="#FF0A0A0A">

    <Window.Resources>
        <!-- Button Style - Matches Windows 11 Fluent Design -->
        <Style x:Key="PrimaryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="$AccentColor"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="32,14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#FF1A86D9"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#FF005A9E"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="SecondaryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#FF2D2D30"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Padding" Value="24,12"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#FF555555"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#FF3D3D40"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        $heroImageSection

        <!-- Main Content Area -->
        <Grid Grid.Row="1" HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="800">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Icon -->
            <Border Grid.Row="0" Width="80" Height="80" CornerRadius="40"
                    Background="$AccentColor" HorizontalAlignment="Center" Margin="0,0,0,30">
                <TextBlock Text="&#xE7BA;" FontFamily="Segoe MDL2 Assets"
                          FontSize="40" Foreground="White"
                          HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>

            <!-- Title -->
            <TextBlock Grid.Row="1" Text="$Title"
                      FontSize="42" FontWeight="Light" Foreground="White"
                      HorizontalAlignment="Center" Margin="0,0,0,8"/>

            <!-- Subtitle (Company Name) -->
            <TextBlock Grid.Row="2" Text="$Subtitle"
                      FontSize="16" Foreground="#FF888888"
                      HorizontalAlignment="Center" Margin="0,0,0,30"/>

            <!-- Headline -->
            <TextBlock Grid.Row="3" Text="$Headline"
                      FontSize="20" FontWeight="SemiBold" Foreground="White"
                      HorizontalAlignment="Center" Margin="0,0,0,16"/>

            <!-- Message -->
            <TextBlock Grid.Row="4" TextWrapping="Wrap" TextAlignment="Center"
                      FontSize="16" Foreground="#FFCCCCCC"
                      HorizontalAlignment="Center" MaxWidth="600" Margin="0,0,0,40">
                $Message
            </TextBlock>

            <!-- Countdown Timer -->
            <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,30">
                <TextBlock Text="$CountdownLabel " FontSize="16" Foreground="#FF888888"/>
                <TextBlock Name="CountdownText" Text="5:00" FontSize="16"
                          Foreground="$AccentColor" FontWeight="Bold"/>
            </StackPanel>

            <!-- Buttons -->
            <StackPanel Grid.Row="6" Orientation="Horizontal" HorizontalAlignment="Center">
                <Button Name="DeferButton" Content="$DeferButtonLabel"
                       Style="{StaticResource SecondaryButtonStyle}"
                       Visibility="$deferVisibility" Margin="0,0,16,0"/>
                <Button Name="UpdateButton" Content="$UpdateButtonLabel"
                       Style="{StaticResource PrimaryButtonStyle}"/>
            </StackPanel>
        </Grid>

        <!-- Close hint (small text at bottom) -->
        <TextBlock Grid.Row="1" Text="Press Escape to minimize (update will proceed automatically)"
                  FontSize="12" Foreground="#FF555555"
                  HorizontalAlignment="Center" VerticalAlignment="Bottom" Margin="0,0,0,40"/>
    </Grid>
</Window>
"@
}

function Get-ToastNotificationWithActionsXaml {
    <#
    .SYNOPSIS
        Returns XAML for an enhanced toast notification with action buttons
    .DESCRIPTION
        Creates a toast-style WPF window with Update Now, Defer, and Dismiss buttons
        for interactive user response when native toast isn't available.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "Update Available",

        [Parameter()]
        [string]$Message,

        [Parameter()]
        [string]$AppName,

        [Parameter()]
        [string]$AccentColor = "#0078D4",

        [Parameter()]
        [string]$UpdateLabel = "Update Now",

        [Parameter()]
        [string]$DeferLabel = "Later",

        [Parameter()]
        [int]$DeferralsRemaining = 5,

        [Parameter()]
        [bool]$CanDefer = $true
    )

    $deferEnabled = if ($CanDefer) { "True" } else { "False" }
    $deferOpacity = if ($CanDefer) { "1" } else { "0.5" }
    $deferContent = if ($CanDefer) { "$DeferLabel ($DeferralsRemaining)" } else { "No deferrals left" }

    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Toast" Height="160" Width="420"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False">
    <Border CornerRadius="8" Background="#FF1F1F1F" BorderBrush="#FF3F3F3F"
            BorderThickness="1" Margin="10">
        <Border.Effect>
            <DropShadowEffect BlurRadius="15" ShadowDepth="3" Opacity="0.5"/>
        </Border.Effect>
        <Grid Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="40"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="30"/>
            </Grid.ColumnDefinitions>

            <!-- Icon -->
            <TextBlock Grid.Row="0" Grid.Column="0" Text="&#xE7E7;" FontFamily="Segoe MDL2 Assets"
                      FontSize="24" Foreground="$AccentColor" VerticalAlignment="Top"/>

            <!-- Content -->
            <StackPanel Grid.Row="0" Grid.Column="1" VerticalAlignment="Top" Margin="10,0">
                <TextBlock Name="TitleText" Text="$Title" Foreground="White"
                          FontSize="14" FontWeight="SemiBold"/>
                <TextBlock Name="AppNameText" Text="$AppName" Foreground="$AccentColor"
                          FontSize="12" Margin="0,2,0,0" Visibility="{Binding HasAppName}"/>
                <TextBlock Name="MessageText" Text="$Message" Foreground="#AAAAAA" FontSize="12"
                          TextWrapping="Wrap" Margin="0,4,0,0"/>
            </StackPanel>

            <!-- Close Button -->
            <Button Name="CloseButton" Grid.Row="0" Grid.Column="2" Content="&#xE711;"
                   FontFamily="Segoe MDL2 Assets" Background="Transparent"
                   Foreground="#888888" BorderThickness="0" Cursor="Hand"
                   VerticalAlignment="Top"/>

            <!-- Action Buttons -->
            <StackPanel Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="3"
                       Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
                <Button Name="DeferButton" Content="$deferContent"
                       IsEnabled="$deferEnabled" Opacity="$deferOpacity"
                       Background="#FF3F3F3F" Foreground="White" BorderThickness="0"
                       Padding="12,6" Margin="0,0,8,0" Cursor="Hand">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="4"
                                    Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
                <Button Name="UpdateButton" Content="$UpdateLabel"
                       Background="$AccentColor" Foreground="White" BorderThickness="0"
                       Padding="12,6" Cursor="Hand">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="4"
                                    Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
}

