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

